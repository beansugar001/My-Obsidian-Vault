proc V159_read {addr label} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase {0x[0-9a-f]+:\s+([0-9a-f]+)} $out -> x]} { error "READ_PARSE $label <$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V159_READ %s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc V159_dmi {reg label} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> x]} { error "DMI_PARSE $label <$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V159_DMI %s reg=0x%X value=0x%08X" $label $reg $v]
    return $v
}
set rc [catch {
    set init [capture {init}]
    echo "V159_PREFLIGHT_INIT_BEGIN"; echo $init; echo "V159_PREFLIGHT_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_FAIL" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_FAIL" }
    if {![regexp -nocase {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "DAPLINK_SERIAL_FAIL" }
    set state [riscv.cpu curstate]
    echo "V159_PREFLIGHT_CPU_INITIAL=$state"
    if {$state eq "running"} {echo "V159_HALT_ATTEMPT"; halt 2000; set state [riscv.cpu curstate]}
    echo "V159_PREFLIGHT_CPU_FINAL=$state"
    if {$state ne "halted"} { error "CPU_NOT_HALTED" }
    set dm [V159_dmi 0x11 DMSTATUS]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} { error "DMSTATUS_NOT_HALTED" }
    set sb [V159_dmi 0x38 SBCS]
    if {$sb & 0x00607000} { error "SBA_BUSY_OR_ERROR" }
    set rst [V159_read 0x40021810 PERI_RST]
    if {$rst != 0} { error "PERI_RST_NOT_ZERO" }
    set cr [V159_read 0x40022000 FLS_CR]
    echo [format "V159_PREFLIGHT_PRECONDITIONS DMSTATUS=0x%08X SBCS=0x%08X PERI_RST=0x%08X FLS_CR=0x%08X" $dm $sb $rst $cr]
    if {($cr & 3) != 0} { error "FLASH_NOT_READONLY_AT_ENTRY" }
    set clk [V159_read 0x4002180C PERI_CLKEN]
    set first [V159_read 0x00000000 FLASH_FIRST]
    set end [V159_read 0x0000043C FLASH_LAST_CANDIDATE]
    dump_image "$::env(V159_SNAPSHOT)" 0x00000000 0x00010000
    echo [format "V159_PREFLIGHT_FLASH clk=0x%08X first=0x%08X end=0x%08X" $clk $first $end]
} err]
if {$rc} { echo "V159_PREFLIGHT=FAIL"; echo "V159_ERROR=$err" } else { echo "V159_PREFLIGHT=PASS" }
echo "V159_PREFLIGHT_COMPLETE"
shutdown


