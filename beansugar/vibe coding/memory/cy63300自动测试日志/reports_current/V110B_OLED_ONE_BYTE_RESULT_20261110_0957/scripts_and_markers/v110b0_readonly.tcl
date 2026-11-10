# V110B0: post-power-cycle read-only gate snapshot. No target MMIO writes.
set ::v110b0_status "INCOMPLETE_OR_UNKNOWN"
set ::v110b0_halt_count 0
proc v110b0_dread {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} { error "DMI_READ_PARSE_FAIL reg=$r raw=<$o>" }
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v110b0_dwrite_setup {r v label} {
    if {$r != 0x38 && $r != 0x39} { error "DMI_SETUP_WRITE_DENIED reg=$r" }
    echo [format "V110B0_DMI_READ_SETUP label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v110b0_sb {label} {
    set s [v110b0_dread 0x38]
    echo [format "V110B0_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "SBA_BUSY_OR_ERROR label=$label value=$s" }
    return $s
}
proc v110b0_read {addr label} {
    v110b0_sb "${label}_PRE"
    v110b0_dwrite_setup 0x38 0x20140404 "${label}_READMODE"
    v110b0_sb "${label}_MODE"
    v110b0_dwrite_setup 0x39 $addr "${label}_ADDRESS"
    set val [v110b0_dread 0x3c]
    v110b0_sb "${label}_DONE"
    v110b0_dwrite_setup 0x38 0x20040404 "${label}_RETURN_IDLE"
    v110b0_sb "${label}_IDLE_CHECK"
    echo [format "V110B0_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $val]
    return $val
}
proc v110b0_triplet {addr label} {
    set vals {}
    foreach n {1 2 3} {
        if {$n > 1} { sleep 20 }
        lappend vals [v110b0_read $addr "${label}_$n"]
    }
    echo [format "V110B0_TRIPLE label=%s values=0x%08X,0x%08X,0x%08X" $label [lindex $vals 0] [lindex $vals 1] [lindex $vals 2]]
    if {[lindex $vals 0] != [lindex $vals 1] || [lindex $vals 1] != [lindex $vals 2]} { error "UNSTABLE_READ $label" }
    return [lindex $vals 0]
}
set rc [catch {
    set init [capture {init}]
    echo "V110B0_INIT_BEGIN"; echo $init; echo "V110B0_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_MISMATCH" }
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]
    echo "V110B0_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} { echo "V110B0_HALT_REQUEST=once"; halt 2000; incr ::v110b0_halt_count; set cpu [riscv.cpu curstate] }
    echo "V110B0_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v110b0_halt_count > 1} { error "CPU_NOT_HALTED" }
    set dm [v110b0_dread 0x11]
    echo [format "V110B0_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "DMSTATUS_NOT_HALTED" }
    v110b0_sb PREFLIGHT
    set clk [v110b0_triplet 0x4002180C PERI_CLKEN]
    set rst [v110b0_triplet 0x40021810 PERI_RST]
    echo [format "V110B0_SYSCTRL CLKEN=0x%08X RST=0x%08X" $clk $rst]
    if {$rst & 0x20} {
        set ::v110b0_status "BLOCKED_I2C_RESET_ASSERTED"
        echo "V110B0_I2C_REGISTERS_SKIPPED_RESET_ASSERTED"
    } elseif {($clk & 0x20) == 0} {
        set ::v110b0_status "PASS_RESET_CLEAR_CLOCK_OFF"
        echo "V110B0_I2C_REGISTERS_SKIPPED_CLOCK_OFF"
    } else {
        set mod [v110b0_triplet 0x40002800 MODULE_CTRL]
        set fifo [v110b0_triplet 0x4000280C FIFO_STA]
        set sta [v110b0_triplet 0x4000283C I2C_STATUS]
        set raw [v110b0_triplet 0x40002858 RAW_INTR]
        echo [format "V110B0_I2C_SNAPSHOT MODULE=0x%08X FIFO=0x%08X STATUS=0x%08X RAW=0x%08X" $mod $fifo $sta $raw]
        set ::v110b0_status "PASS_RESET_CLEAR_CLOCK_ON"
    }
} err]
if {$rc} { set ::v110b0_status "FAIL_OR_UNKNOWN"; echo "V110B0_ERROR=$err" }
set sf [catch {v110b0_sb FINAL} sv]
echo [format "V110B0_FINAL_SBCS rc=%d value=%s" $sf $sv]
echo [format "V110B0_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=0" $::v110b0_status $::v110b0_halt_count]
echo "V110B0_COMPLETE"
shutdown
