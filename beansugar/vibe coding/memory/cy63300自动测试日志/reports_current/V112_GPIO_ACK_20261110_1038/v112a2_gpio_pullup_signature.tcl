# V112A2: test whether GPIOB2/B3 internal pull-ups restore idle-high sampling.
# Exactly one target MMIO write is allowed: GPIOB PUPD 0x4000015C <- 0x300.
set ::v112a2_status "INCOMPLETE_OR_UNKNOWN"
set ::v112a2_write_count 0
set ::v112a2_halt_count 0
set ::v112a2_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
proc v112a2_dread {reg} {
    set o [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL_$reg <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v112a2_dwrite {reg val label} {
    echo [format "V112A2_DMI_SETUP label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$val & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$val & 0xffffffff}]]
}
proc v112a2_read {addr label} {
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_$label"}
    v112a2_dwrite 0x38 0x20140404 "${label}_READMODE"
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READMODE_ERROR_$label"}
    v112a2_dwrite 0x39 $addr "${label}_ADDRESS"
    set v [v112a2_dread 0x3C]
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READ_ERROR_$label"}
    v112a2_dwrite 0x38 0x20040404 "${label}_IDLEMODE"
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_IDLE_ERROR_$label"}
    echo [format "V112A2_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc v112a2_write_pupd_once {} {
    if {$::v112a2_write_count != 0} {error "PUPD_WRITE_BUDGET_EXCEEDED"}
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_BEFORE_PUPD"}
    v112a2_dwrite 0x38 0x20040404 PUPD_WRITEMODE
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_WRITEMODE_ERROR_PUPD"}
    v112a2_dwrite 0x39 0x4000015C PUPD_ADDRESS
    set s [v112a2_dread 0x38]
    if {$s & 0x00607000} {error "SBA_ADDRESS_ERROR_PUPD"}
    set ::v112a2_write_count 1
    echo "V112A2_TARGET_MMIO_WRITE count=1 addr=0x4000015C value=0x00000300 label=GPIOB2_B3_INTERNAL_PULLUP"
    v112a2_dwrite 0x3C 0x300 PUPD_DATA
    set done 0
    for {set i 0} {$i < 100} {incr i} {
        set s [v112a2_dread 0x38]
        if {$s & 0x00407000} {error "SBA_WRITE_ERROR_PUPD value=[format 0x%08X $s]"}
        if {($s & 0x00200000) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {error "SBA_WRITE_TIMEOUT_PUPD"}
}
set rc [catch {
    set init [capture {init}]
    echo "V112A2_INIT_BEGIN"; echo $init; echo "V112A2_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"}
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "PROBE_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]
    echo "V112A2_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {echo "V112A2_HALT_REQUEST=once"; halt 2000; incr ::v112a2_halt_count; set cpu [riscv.cpu curstate]}
    if {$cpu ne "halted" || $::v112a2_halt_count > 1} {error "CPU_NOT_HALTED"}
    set dm [v112a2_dread 0x11]
    echo [format "V112A2_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} {error "DMSTATUS_NOT_HALTED"}
    set sb [v112a2_dread 0x38]
    echo [format "V112A2_SBCS=0x%08X" $sb]
    if {$sb & 0x00607000} {error "SBA_NOT_IDLE"}
    set clk [v112a2_read 0x4002180C PERI_CLKEN]
    set rst [v112a2_read 0x40021810 PERI_RST]
    if {$clk != 1 || $rst != 0} {error [format "SYSCTRL_STATE_MISMATCH CLKEN=%X RST=%X" $clk $rst]}
    set odr [v112a2_read 0x40000100 GPIOB_ODR]
    set dir [v112a2_read 0x40000104 GPIOB_DIR]
    set osod [v112a2_read 0x40000158 GPIOB_OSOD]
    set afr1 [v112a2_read 0x40000168 GPIOB_AFR1]
    set pupd [v112a2_read 0x4000015C GPIOB_PUPD]
    echo [format "V112A2_GPIO_BASE ODR=%08X DIR=%08X OSOD=%08X AFR1=%08X PUPD=%08X" $odr $dir $osod $afr1 $pupd]
    if {$odr != 0 || $dir != 0 || $osod != 0 || $afr1 != 0} {error "GPIO_SAFE_INPUT_BASELINE_MISMATCH"}
    if {$pupd != 0} {error "PUPD_NOT_DEFAULT_ZERO_NO_WRITE"}
    set idr0 [v112a2_read 0x40000150 IDR_BEFORE_PULLUP]
    echo [format "V112A2_IDR_BEFORE=0x%08X PB2=%d PB3=%d" $idr0 [expr {($idr0>>2)&1}] [expr {($idr0>>3)&1}]]
    if {($idr0 & 0xC) != 0} {error "EXPECTED_LOW_INPUT_BASELINE_CHANGED_NO_WRITE"}
    v112a2_write_pupd_once
    set pupd2 [v112a2_read 0x4000015C PUPD_AFTER_WRITE]
    set idr1 [v112a2_read 0x40000150 IDR_AFTER_PULLUP]
    if {$pupd2 != 0x300} {error [format "PUPD_READBACK_MISMATCH got=%08X" $pupd2]}
    echo [format "V112A2_IDR_AFTER=0x%08X PB2=%d PB3=%d MASK=0x%X" $idr1 [expr {($idr1>>2)&1}] [expr {($idr1>>3)&1}] [expr {$idr1&0xC}]]
    if {($idr1 & 0xC) == 0xC} {set ::v112a2_status "PASS_INTERNAL_PULLUPS_RESTORE_IDLE_HIGH"} else {set ::v112a2_status "FAIL_LINES_STILL_LOW"}
} err]
if {$rc} {set ::v112a2_status "FAIL_OR_UNKNOWN"; echo "V112A2_ERROR=$err"}
set final_sb "UNKNOWN"; catch {set final_sb [v112a2_dread 0x38]}
echo [format "V112A2_RESULT=%s WRITE_COUNT=%d FINAL_SBCS=%s" $::v112a2_status $::v112a2_write_count $final_sb]
echo "V112A2_COMPLETE"
shutdown
