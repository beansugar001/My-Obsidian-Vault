# Read-only snapshot after V114 DPC side-effect investigation.
if {![info exists ::v114c_authorized] || $::v114c_authorized != 1} { error "V114C_AUTH_REQUIRED" }
set ::v114c_reads 0
set ::v114c_status "INCOMPLETE_OR_UNKNOWN"
set ::v114c_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
proc v114c_dr {r} {
    set raw [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> h]} { error "V114C_DMI_READ_PARSE_FAIL:$r:$raw" }
    scan $h %x v
    return [expr {$v & 0xffffffff}]
}
proc v114c_dw {r v label} {
    echo [format "V114C_DMI_SETUP label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v114c_sb {label} {
    set s [v114c_dr 0x38]
    echo [format "V114C_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "V114C_SBA_BUSY_OR_ERROR:$label" }
}
proc v114c_rd {a label} {
    v114c_sb "${label}_PRE"
    v114c_dw 0x38 0x20140404 "${label}_READ_MODE"
    v114c_sb "${label}_MODE"
    v114c_dw 0x39 $a "${label}_ADDRESS"
    set v [v114c_dr 0x3C]
    v114c_sb "${label}_DONE"
    incr ::v114c_reads
    echo [format "V114C_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]
    return $v
}
set rc [catch {
    set init [capture {init}]
    echo "V114C_INIT_BEGIN"; echo $init; echo "V114C_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "V114C_JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init] || ![regexp $::v114c_serial $init]} { error "V114C_TARGET_IDENTITY_FAIL" }
    set state [riscv.cpu curstate]
    if {$state ne "halted"} { error "V114C_CPU_NOT_HALTED_NO_READS" }
    set dm [v114c_dr 0x11]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} { error "V114C_DMSTATUS_NOT_HALTED" }
    echo [format "V114C_DMSTATUS=0x%08X" $dm]
    set clk [v114c_rd 0x4002180C PERI_CLKEN]
    set rst [v114c_rd 0x40021810 PERI_RST]
    if {($clk & 0x20) == 0} {
        set ::v114c_status "PASS_CLOCK_OFF_I2C_REGS_SKIPPED"
    } else {
        set module [v114c_rd 0x40002800 MODULE_CTRL]
        set fifo [v114c_rd 0x4000280C FIFO_STA]
        set div0 [v114c_rd 0x40002810 CLK_DIV0]
        set div1 [v114c_rd 0x40002814 CLK_DIV1]
        set mode [v114c_rd 0x40002820 MODE]
        set addr [v114c_rd 0x40002824 ADDR]
        set mctr [v114c_rd 0x40002828 MCTR]
        set hold [v114c_rd 0x40002838 HOLD]
        set status [v114c_rd 0x4000283C I2C_STATUS]
        set raw [v114c_rd 0x40002858 RAW_INTR]
        set idr [v114c_rd 0x40000150 GPIOB_IDR]
        echo [format "V114C_SNAPSHOT clken=0x%08X rst=0x%08X module=0x%08X fifo=0x%08X div0=0x%08X div1=0x%08X mode=0x%08X addr=0x%08X mctr=0x%08X hold=0x%08X status=0x%08X raw=0x%08X idr=0x%08X" $clk $rst $module $fifo $div0 $div1 $mode $addr $mctr $hold $status $raw $idr]
        set ::v114c_status "PASS_READONLY_SNAPSHOT"
    }
} err]
if {$rc} { set ::v114c_status "FAIL_OR_UNKNOWN"; echo "V114C_ERROR=$err" }
set finalrc [catch {v114c_sb FINAL} finals]
echo [format "V114C_RESULT=%s MMIO_READ_COUNT=%d FINAL_SBCS_RC=%d DETAIL=%s" $::v114c_status $::v114c_reads $finalrc $finals]
echo "V114C_COMPLETE"
shutdown

