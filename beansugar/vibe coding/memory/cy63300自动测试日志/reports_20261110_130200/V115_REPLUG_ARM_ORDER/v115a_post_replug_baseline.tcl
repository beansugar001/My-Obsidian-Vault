# V115A: independent post-replug read-only baseline. No target MMIO writes.
set ::v115a_status "INCOMPLETE_OR_UNKNOWN"
set ::v115a_halt_count 0
proc v115a_dr {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL reg=$r raw=<$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v115a_dwrite {r v label} {
    # DMI setup writes only; whitelist required for SBA reads.
    if {$r != 0x38 && $r != 0x39} {error "DMI_SETUP_WRITE_DENIED reg=$r"}
    echo [format "V115A_DMI_SETUP_WRITE label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v115a_sb {label} {
    set s [v115a_dr 0x38]
    echo [format "V115A_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR label=$label sbcs=[format 0x%08X $s]"}
    return $s
}
proc v115a_read {a label} {
    v115a_sb "${label}_PRE"
    v115a_dwrite 0x38 0x20140404 "${label}_READ_MODE"
    v115a_sb "${label}_MODE"
    v115a_dwrite 0x39 $a "${label}_ADDRESS"
    set v [v115a_dr 0x3c]
    v115a_sb "${label}_DONE"
    v115a_dwrite 0x38 0x20040404 "${label}_RETURN_IDLE"
    v115a_sb "${label}_IDLE"
    echo [format "V115A_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]
    return $v
}
proc v115a_triplet {a label} {
    set vals {}
    foreach n {1 2 3} {
        if {$n > 1} {sleep 10}
        lappend vals [v115a_read $a "${label}_$n"]
    }
    set x [lindex $vals 0]; set y [lindex $vals 1]; set z [lindex $vals 2]
    echo [format "V115A_TRIPLET label=%s values=%08X,%08X,%08X" $label $x $y $z]
    if {$x != $y || $y != $z} {error "UNSTABLE_READ label=$label"}
    return $x
}
set rc [catch {
    set init [capture {init}]
    echo "V115A_INIT_BEGIN"; echo $init; echo "V115A_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"}
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]; echo "V115A_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {capture {halt 2000}; incr ::v115a_halt_count; set cpu [riscv.cpu curstate]}
    echo "V115A_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v115a_halt_count > 1} {error "CPU_NOT_HALTED"}
    set dm [v115a_dr 0x11]; echo [format "V115A_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} {error "DMSTATUS_NOT_HALTED"}
    v115a_sb PREFLIGHT
    set clk [v115a_triplet 0x4002180C PERI_CLKEN]
    set rst [v115a_triplet 0x40021810 PERI_RST]
    echo [format "V115A_SYSCTRL CLKEN=0x%08X RST=0x%08X" $clk $rst]
    if {$rst & 0x20} {error "I2C_RESET_ASSERTED; INTERNAL_READS_SKIPPED"}
    if {$clk & 0x20} {
        foreach {label addr} {GPIOB_ODR 0x40000100 GPIOB_DIR 0x40000104 GPIOB_IDR 0x40000150 GPIOB_OSOD 0x40000158 GPIOB_AFR1 0x40000168 MODULE_CTRL 0x40002800 FIFO_STA 0x4000280C CLK_DIV0 0x40002810 CLK_DIV1 0x40002814 MODE 0x40002820 ADDR 0x40002824 MCTR 0x40002828 HOLD 0x40002838 STATUS 0x4000283C RAW_INTR 0x40002858} {
            set v [v115a_read $addr $label]
            echo [format "V115A_REG label=%s value=0x%08X" $label $v]
        }
        set ::v115a_status "PASS_CLOCK_ON_READONLY_SNAPSHOT"
    } else {
        set ::v115a_status "PASS_CLOCK_OFF_CLASSIFIED_I2C_READS_SKIPPED"
        echo "V115A_I2C_INTERNAL_READS_SKIPPED_CLOCK_OFF"
    }
} err]
if {$rc} {set ::v115a_status "FAIL_OR_UNKNOWN"; echo "V115A_ERROR=$err"}
set sbrc [catch {v115a_sb FINAL} sbv]; echo [format "V115A_FINAL_SBCS rc=%d value=%s" $sbrc $sbv]
set dmrc [catch {v115a_dr 0x11} dmv]; echo [format "V115A_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv]
echo [format "V115A_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=0" $::v115a_status $::v115a_halt_count]
echo "V115A_COMPLETE"
shutdown
