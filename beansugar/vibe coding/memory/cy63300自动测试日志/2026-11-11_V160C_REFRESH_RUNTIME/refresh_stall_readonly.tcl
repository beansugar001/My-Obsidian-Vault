proc V160_read {addr label} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase {0x[0-9a-f]+:\s+([0-9a-f]+)} $out -> x]} { error "READ_PARSE $label <$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V160_READ %s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc V160_dmi {reg label} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> x]} { error "DMI_PARSE $label <$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V160_DMI %s reg=0x%X value=0x%08X" $label $reg $v]
    return $v
}
set rc [catch {
    set init [capture {init}]
    echo "V160C_READONLY_INIT_BEGIN"; echo $init; echo "V160C_READONLY_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_FAIL" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_FAIL" }
    if {![regexp -nocase {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "DAPLINK_SERIAL_FAIL" }
    set state [riscv.cpu curstate]
    echo "V160C_READONLY_CPU_INITIAL=$state"
    if {$state ne "halted" && $state ne "running"} {error "UNEXPECTED_HART_STATE"}
    set dm [V160_dmi 0x11 DMSTATUS]
    if {($state eq "halted" && ($dm & 0xF00) != 0x300) ||
        ($state eq "running" && ($dm & 0xF00) != 0xC00)} {error "DMSTATUS_STATE_MISMATCH"}
    set sb [V160_dmi 0x38 SBCS]
    if {$sb & 0x00607000} { error "SBA_BUSY_OR_ERROR" }
    set rst [V160_read 0x40021810 PERI_RST]
    if {$rst != 0} { error "PERI_RST_NOT_ZERO" }
    set cr [V160_read 0x40022000 FLS_CR]
    echo [format "V160C_READONLY_PRECONDITIONS DMSTATUS=0x%08X SBCS=0x%08X PERI_RST=0x%08X FLS_CR=0x%08X" $dm $sb $rst $cr]
    if {($cr & 3) != 0} { error "FLASH_NOT_READONLY_AT_ENTRY" }
    set clk [V160_read 0x4002180C PERI_CLKEN]
    if {($clk & 0x20) == 0} {error "I2C_CLOCK_OFF"}
    for {set sample 0} {$sample < 3} {incr sample} {
        foreach {addr label} {
            0x40000268 GPIOC_AFR1
            0x40002800 MODULE_CTRL
            0x40002828 MCTR
            0x4000280C FIFO_STA
            0x4000283C I2C_STA
            0x40002858 RAW
        } {
            V160_read $addr $label
        }
        sleep 20
    }

} err]
if {$rc} { echo "V160C_READONLY=FAIL"; echo "V160_ERROR=$err" } else { echo "V160C_READONLY=PASS" }
echo "V160C_READONLY_COMPLETE"
shutdown


