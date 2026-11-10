set ::v113a4_status "INCOMPLETE"
proc v113a4_dr {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL reg=$r <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v113a4_dw {r v label} {
    echo [format "V113A4_DMI_SETUP label=%s reg=0x%02X value=0x%08X" $label $r $v]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" $v]
}
proc v113a4_sb {label} {
    set s [v113a4_dr 0x38]
    echo [format "V113A4_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR label=$label value=[format 0x%08X $s]"}
}
proc v113a4_rd {a label} {
    v113a4_sb "${label}_PRE"
    v113a4_dw 0x38 0x20140404 "${label}_READ_MODE"
    v113a4_sb "${label}_MODE"
    v113a4_dw 0x39 $a "${label}_ADDRESS"
    set v [v113a4_dr 0x3c]
    v113a4_sb "${label}_DONE"
    echo [format "V113A4_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]
    return $v
}
set rc [catch {
    set il [capture {init}]
    echo "V113A4_INIT_BEGIN"; echo $il; echo "V113A4_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} {error "TAP_OR_IDCODE_MISMATCH"}
    if {![regexp {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} {error "DAPLINK_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]
    echo "V113A4_CPU_STATE=$cpu"
    if {$cpu ne "halted"} {error "CPU_NOT_HALTED_READONLY_STAGE_STOP"}
    set dm [v113a4_dr 0x11]
    echo [format "V113A4_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} {error "DMSTATUS_NOT_HALTED"}
    v113a4_sb PREFLIGHT
    foreach {label a} {
        PERI_CLKEN 0x4002180C PERI_RST 0x40021810
        MODULE_CTRL 0x40002800 FIFO_STA_1 0x4000280C STATUS_1 0x4000283C RAW_1 0x40002858
        ADDR 0x40002824 MCTR 0x40002828 GPIOB_IDR 0x40000150
        FIFO_STA_2 0x4000280C STATUS_2 0x4000283C RAW_2 0x40002858
        FIFO_STA_3 0x4000280C STATUS_3 0x4000283C RAW_3 0x40002858
    } {v113a4_rd $a $label}
    set ::v113a4_status "PASS_READONLY_CAPTURE"
} err]
if {$rc} {set ::v113a4_status "FAIL_OR_UNKNOWN"; echo "V113A4_ERROR=$err"}
set sb_rc [catch {v113a4_sb FINAL} sb_val]
echo [format "V113A4_RESULT=%s TARGET_MMIO_WRITE_COUNT=0 SBCS_RC=%d SBCS=%s" $::v113a4_status $sb_rc $sb_val]
echo "V113A4_COMPLETE"
shutdown
