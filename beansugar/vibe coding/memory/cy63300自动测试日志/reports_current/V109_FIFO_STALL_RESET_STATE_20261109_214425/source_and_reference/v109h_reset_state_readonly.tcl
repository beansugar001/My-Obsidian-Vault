# V109H: independently confirm the current soft-reset register after V109G.
# Target MMIO write budget: zero. A single halt request is allowed if needed.
set ::v109h_status "INCOMPLETE_OR_UNKNOWN"
set ::v109h_halt_count 0
proc v109h_dr {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} { error "DMI_READ_PARSE_FAIL reg=$r raw=<$o>" }
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v109h_dw {r v label} {
    if {$r != 0x38 && $r != 0x39} { error "DMI_SETUP_WRITE_DENIED reg=$r" }
    echo [format "V109H_DMI_READ_SETUP label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v109h_sb {label} {
    set s [v109h_dr 0x38]
    echo [format "V109H_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "SBA_BUSY_OR_ERROR label=$label value=$s" }
    return $s
}
proc v109h_read {addr label} {
    v109h_sb "${label}_PRE"
    v109h_dw 0x38 0x20140404 "${label}_READ_MODE"
    v109h_sb "${label}_MODE"
    v109h_dw 0x39 $addr "${label}_ADDRESS"
    set v [v109h_dr 0x3c]
    v109h_sb "${label}_DONE"
    v109h_dw 0x38 0x20040404 "${label}_RETURN_IDLE"
    v109h_sb "${label}_RETURN_IDLE_CHECK"
    echo [format "V109H_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
set rc [catch {
    set init [capture {init}]
    echo "V109H_INIT_BEGIN"; echo $init; echo "V109H_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_MISMATCH" }
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]
    echo "V109H_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} { echo "V109H_HALT_REQUEST=once"; halt 2000; incr ::v109h_halt_count; set cpu [riscv.cpu curstate] }
    echo "V109H_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v109h_halt_count > 1} { error "CPU_NOT_HALTED" }
    set dm [v109h_dr 0x11]
    echo [format "V109H_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "DMSTATUS_NOT_HALTED" }
    v109h_sb PREFLIGHT
    set vals {}
    foreach n {1 2 3} {
        if {$n > 1} { sleep 100 }
        lappend vals [v109h_read 0x40021810 "PERI_RST_$n"]
    }
    echo [format "V109H_PERI_RST_TRIPLE=0x%08X,0x%08X,0x%08X" [lindex $vals 0] [lindex $vals 1] [lindex $vals 2]]
    if {[lindex $vals 0] != [lindex $vals 1] || [lindex $vals 1] != [lindex $vals 2]} { error "PERI_RST_UNSTABLE" }
    echo [format "V109H_PERI_RST_I2C_BIT5=%d" [expr {([lindex $vals 0] >> 5) & 1}]]
    set ::v109h_status "PASS_READONLY_STABLE"
} err]
if {$rc} { set ::v109h_status "FAIL_OR_UNKNOWN"; echo "V109H_ERROR=$err" }
set sf [catch {v109h_sb FINAL} sv]
echo [format "V109H_FINAL_SBCS rc=%d value=%s" $sf $sv]
echo [format "V109H_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=0" $::v109h_status $::v109h_halt_count]
echo "V109H_COMPLETE"
shutdown
