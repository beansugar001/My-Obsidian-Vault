# V112A3: one GPIO-only 0x3C write-address frame, then ACK sample and STOP.
# Hardware I2C remains clock-gated; no OLED command/data is sent.
set ::v112a3_status "INCOMPLETE_OR_UNKNOWN"
set ::v112a3_ack "NOT_SAMPLED"
set ::v112a3_writes 0
set ::v112a3_halts 0
set ::v112a3_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
proc v112a3_dread {reg} {
    set o [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL_$reg <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v112a3_dwrite {reg val label} {
    echo [format "V112A3_DMI_SETUP label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$val & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$val & 0xffffffff}]]
}
proc v112a3_read {addr label} {
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_$label"}
    v112a3_dwrite 0x38 0x20140404 "${label}_READMODE"
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READMODE_ERROR_$label"}
    v112a3_dwrite 0x39 $addr "${label}_ADDRESS"
    set v [v112a3_dread 0x3C]
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READ_ERROR_$label"}
    v112a3_dwrite 0x38 0x20040404 "${label}_IDLEMODE"
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_IDLE_ERROR_$label"}
    echo [format "V112A3_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc v112a3_write {addr val label} {
    if {$::v112a3_writes >= 37} {error "GPIO_FRAME_WRITE_BUDGET_EXCEEDED"}
    set allowed 0
    if {$addr == 0x40000100 && $val in {0x1 0x4 0x5 0x9 0xC 0xD}} {set allowed 1}
    if {$addr == 0x40000104 && $val in {0x0 0x8 0xC}} {set allowed 1}
    if {$addr == 0x40000158 && $val == 0xC} {set allowed 1}
    if {!$allowed} {error [format "TARGET_WRITE_DENIED_%s_%08X_%08X" $label $addr $val]}
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_BEFORE_WRITE_$label"}
    v112a3_dwrite 0x38 0x20040404 "${label}_WRITEMODE"
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_WRITEMODE_ERROR_$label"}
    v112a3_dwrite 0x39 $addr "${label}_ADDRESS"
    set s [v112a3_dread 0x38]
    if {$s & 0x00607000} {error "SBA_ADDRESS_ERROR_$label"}
    incr ::v112a3_writes
    echo [format "V112A3_TARGET_MMIO_WRITE count=%d addr=0x%08X value=0x%08X label=%s" $::v112a3_writes $addr $val $label]
    v112a3_dwrite 0x3C $val "${label}_DATA"
    set done 0
    for {set i 0} {$i < 100} {incr i} {
        set s [v112a3_dread 0x38]
        if {$s & 0x00407000} {error "SBA_WRITE_ERROR_$label"}
        if {($s & 0x00200000) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {error "SBA_WRITE_TIMEOUT_$label"}
    set got [v112a3_read $addr "${label}_VERIFY"]
    set mask 0xC
    if {($got & $mask) != ($val & $mask)} {error [format "GPIO_WRITE_VERIFY_FAIL_%s got=%08X expected=%08X" $label $got $val]}
    return $got
}
proc v112a3_sample {label} {
    set v [v112a3_read 0x40000150 $label]
    echo [format "V112A3_LINE label=%s PB2_SCL=%d PB3_SDA=%d MASK=0x%X" $label [expr {($v>>2)&1}] [expr {($v>>3)&1}] [expr {$v&0xC}]]
    return $v
}
proc v112a3_expect {val expected label} {
    set got [expr {$val & 0xC}]
    if {$got != $expected} {error [format "LINE_LEVEL_MISMATCH_%s expected=%X got=%X" $label $expected $got]}
}
set rc [catch {
    set init [capture {init}]
    echo "V112A3_INIT_BEGIN"; echo $init; echo "V112A3_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"}
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "PROBE_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]
    echo "V112A3_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {echo "V112A3_HALT_REQUEST=once"; halt 2000; incr ::v112a3_halts; set cpu [riscv.cpu curstate]}
    if {$cpu ne "halted" || $::v112a3_halts > 1} {error "CPU_NOT_HALTED"}
    set dm [v112a3_dread 0x11]
    echo [format "V112A3_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} {error "DMSTATUS_NOT_HALTED"}
    set sb [v112a3_dread 0x38]
    if {$sb & 0x00607000} {error "SBA_NOT_IDLE"}
    set clk [v112a3_read 0x4002180C PERI_CLKEN]
    set rst [v112a3_read 0x40021810 PERI_RST]
    if {$clk != 1 || $rst != 0} {error "SYSCTRL_STATE_MISMATCH"}
    set pupd [v112a3_read 0x4000015C GPIOB_PUPD]
    set odr [v112a3_read 0x40000100 GPIOB_ODR]
    set dir [v112a3_read 0x40000104 GPIOB_DIR]
    set osod [v112a3_read 0x40000158 GPIOB_OSOD]
    set afr1 [v112a3_read 0x40000168 GPIOB_AFR1]
    if {$pupd != 0x300 || $odr != 0 || $dir != 0 || $osod != 0 || $afr1 != 0} {error "GPIO_BASELINE_MISMATCH"}
    set clken [v112a3_read 0x4002180C VERIFY_I2C_CLOCK_STILL_OFF]
    if {($clken & 0x20) != 0} {error "I2C_CLOCK_MUST_REMAIN_OFF"}
    set idle [v112a3_sample LINES_BEFORE_FRAME]
    v112a3_expect $idle 0xC BUS_IDLE_BEFORE_FRAME
    # Configure GPIO open-drain output with released latch, then recheck idle-high.
    v112a3_write 0x40000100 0xC GPIOB_ODR_RELEASE
    v112a3_write 0x40000158 0xC GPIOB_OSOD_ENABLE
    v112a3_write 0x40000104 0xC GPIOB_DIR_ENABLE
    v112a3_expect [v112a3_sample GPIO_CONFIG_IDLE] 0xC GPIO_CONFIG_IDLE
    # START: SDA falls while SCL released, then SCL is driven low by DIR gating.
    v112a3_write 0x40000100 0x5 START_SDA_LOW
    v112a3_expect [v112a3_sample START_SDA] 4 START_SDA
    v112a3_write 0x40000100 0x1 START_PRELOAD_SCL_LOW
    v112a3_write 0x40000104 0xC START_SCL_LOW
    v112a3_expect [v112a3_sample START_COMPLETE] 0 START_COMPLETE
    # One address byte: 0x78 = 7-bit OLED address 0x3C plus W=0.
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {(0x78 >> $i) & 1}]
        set odr [expr {1 | ($bit ? 8 : 0)}]
        v112a3_write 0x40000100 $odr [format "ADDR_BIT_%d_DATA_%d" $i $bit]
        v112a3_expect [v112a3_sample [format "ADDR_BIT_%d_LOW" $i]] [expr {$bit ? 8 : 0}] [format "ADDR_BIT_%d_LOW" $i]
        v112a3_write 0x40000104 0x8 [format "ADDR_BIT_%d_SCL_RELEASE" $i]
        after 2
        v112a3_expect [v112a3_sample [format "ADDR_BIT_%d_HIGH" $i]] [expr {$bit ? 0xC : 4}] [format "ADDR_BIT_%d_HIGH" $i]
        v112a3_write 0x40000104 0xC [format "ADDR_BIT_%d_SCL_FALL" $i]
        v112a3_expect [v112a3_sample [format "ADDR_BIT_%d_FALL_SAMPLE" $i]] [expr {$bit ? 8 : 0}] [format "ADDR_BIT_%d_FALL" $i]
    }
    v112a3_write 0x40000100 0x9 ACK_RELEASE_SDA
    v112a3_expect [v112a3_sample ACK_SDA_RELEASED] 8 ACK_SDA_RELEASED
    v112a3_write 0x40000104 0x8 ACK_CLOCK_RELEASE
    after 2
    set ackline [expr {[v112a3_sample ACK_SAMPLE] & 0xC}]
    if {$ackline == 4} {set ::v112a3_ack "ACK"} elseif {$ackline == 0xC} {set ::v112a3_ack "NACK"} else {error "ACK_SAMPLE_INVALID_LINE_STATE"}
    echo [format "V112A3_ACK_SAMPLE=%s SCL_SDA_MASK=0x%X" $::v112a3_ack $ackline]
    # STOP once and release both lines.
    v112a3_write 0x40000104 0xC STOP_SCL_LOW
    v112a3_write 0x40000100 0x1 STOP_PREP_SDA_LOW
    v112a3_expect [v112a3_sample STOP_PREP] 0 STOP_PREP
    v112a3_write 0x40000104 0x8 STOP_SCL_RELEASE
    v112a3_expect [v112a3_sample STOP_SCL_HIGH] 4 STOP_SCL_HIGH
    v112a3_write 0x40000100 0x9 STOP_RELEASE_SDA
    v112a3_expect [v112a3_sample FINAL_IDLE] 0xC FINAL_IDLE
    set ::v112a3_status [expr {$::v112a3_ack eq "ACK" ? "PASS_ADDRESS_ACK_STOP_IDLE" : "PASS_ADDRESS_NACK_STOP_IDLE"}]
} err]
if {$rc} {
    set ::v112a3_status "FAIL_OR_UNKNOWN"
    echo "V112A3_ERROR=$err"
    if {$::v112a3_writes > 0} {catch {v112a3_write 0x40000104 0x0 ERROR_RELEASE_GPIO_LINES}}
}
set final_sb "UNKNOWN"; catch {set final_sb [v112a3_dread 0x38]}
set final_idr "UNKNOWN"; catch {set final_idr [v112a3_read 0x40000150 FINAL_IDR]}
echo [format "V112A3_RESULT=%s ACK=%s WRITE_COUNT=%d HALT_COUNT=%d FINAL_SBCS=%s FINAL_IDR=%s" $::v112a3_status $::v112a3_ack $::v112a3_writes $::v112a3_halts $final_sb $final_idr]
echo "V112A3_COMPLETE"
shutdown
