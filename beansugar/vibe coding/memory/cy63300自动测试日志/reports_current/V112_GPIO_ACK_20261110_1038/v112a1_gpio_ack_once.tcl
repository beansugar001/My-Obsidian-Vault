# V112A1: one fresh post-power-cycle GPIO bit-bang probe, OLED address 0x3C only.
# I2C controller clock/FIFO/enable are never touched. Only GPIO clock bit0 is enabled.
set ::v112_status "INCOMPLETE_OR_UNKNOWN"
set ::v112_writes 0
set ::v112_halts 0
set ::v112_ack "NOT_SAMPLED"
set ::v112_serial "07000001006700343500000a4e57354aa5a5a5a597969908"

proc v112_read32 {addr label} {
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_BEFORE_READ_$label"}
    v112_dwrite 0x38 0x20140404 "${label}_READMODE"
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READMODE_ERROR_$label"}
    v112_dwrite 0x39 $addr "${label}_ADDRESS"
    set val [v112_dread 0x3c]
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_READ_ERROR_$label"}
    v112_dwrite 0x38 0x20040404 "${label}_IDLEMODE"
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_IDLE_ERROR_$label"}
    echo [format "V112_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $val]
    return $val
}
proc v112_dread {reg} {
    set o [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL_$reg <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v112_dwrite {reg val label} {
    echo [format "V112_DMI_SETUP label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$val & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$val & 0xffffffff}]]
}
proc v112_write32 {addr val label} {
    if {$::v112_writes >= 38} {error "TARGET_WRITE_BUDGET_EXCEEDED"}
    # Explicit allowlist: GPIO clock, GPIOB ODR/DIR/OSOD only.
    set allowed 0
    if {$addr == 0x4002180C && $val == 0x1} {set allowed 1}
    if {$addr == 0x40000100 && $val in {0x1 0x4 0x5 0x9 0xC 0xD}} {set allowed 1}
    if {$addr == 0x40000104 && $val in {0x0 0x8 0xC}} {set allowed 1}
    if {$addr == 0x40000158 && $val == 0xC} {set allowed 1}
    if {!$allowed} {error [format "TARGET_WRITE_DENIED_%s_addr_%08X_value_%08X" $label $addr $val]}
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_NOT_IDLE_BEFORE_WRITE_$label"}
    v112_dwrite 0x38 0x20040404 "${label}_WRITEMODE"
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_WRITEMODE_ERROR_$label"}
    v112_dwrite 0x39 $addr "${label}_ADDRESS"
    set s [v112_dread 0x38]
    if {$s & 0x00607000} {error "SBA_ADDRESS_ERROR_$label"}
    incr ::v112_writes
    echo [format "V112_TARGET_MMIO_WRITE count=%d addr=0x%08X value=0x%08X label=%s" $::v112_writes $addr $val $label]
    v112_dwrite 0x3c $val "${label}_DATA"
    set done 0
    for {set i 0} {$i < 100} {incr i} {
        set s [v112_dread 0x38]
        if {$s & 0x00407000} {error "SBA_WRITE_ERROR_$label value=[format 0x%08X $s]"}
        if {($s & 0x00200000) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {error "SBA_WRITE_TIMEOUT_$label"}
    set got [v112_read32 $addr "${label}_VERIFY"]
    set mask 0xC
    if {$addr == 0x4002180C} {set mask 0x1}
    if {($got & $mask) != ($val & $mask)} {error [format "WRITE_VERIFY_FAIL_%s got=%08X expected=%08X mask=%08X" $label $got $val $mask]}
    return $got
}
proc v112_expect {idr expected label} {
    set got [expr {$idr & 0xC}]
    if {$got != $expected} {error [format "LINE_LEVEL_MISMATCH_%s expected=%X got=%X" $label $expected $got]}
}
proc v112_sample {label} {
    set v [v112_read32 0x40000150 $label]
    echo [format "V112_GPIO_LEVEL label=%s PB2_SCL=%d PB3_SDA=%d mask=0x%X" $label [expr {($v>>2)&1}] [expr {($v>>3)&1}] [expr {$v&0xC}]]
    return $v
}

set rc [catch {
    set init [capture {init}]
    echo "V112_INIT_BEGIN"; echo $init; echo "V112_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"}
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "PROBE_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]
    echo "V112_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {echo "V112_HALT_REQUEST=once"; halt 2000; incr ::v112_halts; set cpu [riscv.cpu curstate]}
    if {$cpu ne "halted" || $::v112_halts > 1} {error "CPU_NOT_HALTED"}
    set dm [v112_dread 0x11]
    echo [format "V112_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} {error "DMSTATUS_NOT_HALTED"}
    set sb [v112_dread 0x38]
    echo [format "V112_SBCS_PREFLIGHT=0x%08X" $sb]
    if {$sb & 0x00607000} {error "SBA_NOT_IDLE"}
    set clk [v112_read32 0x4002180C PERI_CLKEN]
    set rst [v112_read32 0x40021810 PERI_RST]
    echo [format "V112_BASELINE CLKEN=0x%08X RST=0x%08X" $clk $rst]
    if {$clk != 0 || $rst != 0} {error "SYSCTRL_BASELINE_MISMATCH"}
    # Open only GPIO clock bit0. Do not read GPIO registers while their clock is gated.
    v112_write32 0x4002180C 0x1 GPIO_CLOCK_ENABLE
    set clk2 [v112_read32 0x4002180C GPIO_CLOCK_VERIFY]
    if {$clk2 != 1} {error "GPIO_CLOCK_VERIFY_FAIL"}
    set odr [v112_read32 0x40000100 GPIOB_ODR]
    set dir [v112_read32 0x40000104 GPIOB_DIR]
    set osod [v112_read32 0x40000158 GPIOB_OSOD]
    set afr1 [v112_read32 0x40000168 GPIOB_AFR1]
    if {$odr != 0 || $dir != 0 || $osod != 0 || $afr1 != 0} {error "GPIO_RESET_BASELINE_MISMATCH"}
    set before [v112_sample GPIO_LINES_BEFORE_SETUP]
    if {($before & 0xC) != 0xC} {error "BUS_NOT_IDLE_HIGH_BEFORE_CONFIG"}
    # Open-drain, pre-load released latch, then enable GPIOB2/B3 outputs.
    v112_write32 0x40000100 0xC GPIOB_ODR_RELEASE_B2_B3
    v112_write32 0x40000158 0xC GPIOB_OSOD_B2_B3
    v112_write32 0x40000104 0xC GPIOB_DIR_OUTPUT_RELEASED
    set idle [v112_sample GPIO_IDLE_AFTER_SETUP]
    if {($idle & 0xC) != 0xC} {error "BUS_NOT_IDLE_HIGH"}
    # START: keep SCL released/high; pull SDA low.
    v112_write32 0x40000100 0x5 START_SDA_LOW
    v112_expect [v112_sample START_SDA_LOW_SAMPLE] 0x4 START_SDA_LOW
    # Pull SCL low using the already validated DIR gating behavior.
    v112_write32 0x40000100 0x1 START_PRELOAD_SCL_LOW
    v112_write32 0x40000104 0xC START_SCL_LOW
    v112_expect [v112_sample START_COMPLETE] 0x0 START_COMPLETE
    # Send address byte 0x78 MSB first. DIR=8 releases SCL; DIR=0xC pulls low.
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {(0x78 >> $i) & 1}]
        set odr [expr {1 | ($bit ? 8 : 0)}]
        v112_write32 0x40000100 $odr [format "ADDR_BIT_%d_DATA_%d" $i $bit]
        v112_expect [v112_sample [format "ADDR_BIT_%d_SCL_LOW" $i]] [expr {$bit ? 8 : 0}] [format "BIT%d_LOW" $i]
        v112_write32 0x40000104 0x8 [format "ADDR_BIT_%d_SCL_RELEASE" $i]
        after 2
        v112_expect [v112_sample [format "ADDR_BIT_%d_SCL_HIGH" $i]] [expr {$bit ? 0xC : 4}] [format "BIT%d_HIGH" $i]
        v112_write32 0x40000104 0xC [format "ADDR_BIT_%d_SCL_FALL" $i]
        v112_expect [v112_sample [format "ADDR_BIT_%d_SCL_FALL_SAMPLE" $i]] [expr {$bit ? 8 : 0}] [format "BIT%d_FALL" $i]
    }
    # Ninth clock: SDA released; low means ACK, high means NACK.
    v112_write32 0x40000100 0x9 ACK_RELEASE_SDA
    v112_expect [v112_sample ACK_SDA_RELEASED] 0x8 ACK_SDA_RELEASED
    v112_write32 0x40000104 0x8 ACK_CLOCK_RELEASE
    after 2
    set ackline [expr {[v112_sample ACK_SAMPLE] & 0xC}]
    if {$ackline == 4} {set ::v112_ack "ACK"} elseif {$ackline == 0xC} {set ::v112_ack "NACK"} else {error "ACK_SAMPLE_INVALID_LINE_STATE"}
    echo [format "V112_ACK_SAMPLE=%s SCL_SDA_MASK=0x%X" $::v112_ack $ackline]
    # One STOP and release, regardless of ACK/NACK.
    v112_write32 0x40000104 0xC STOP_SCL_LOW
    v112_write32 0x40000100 0x1 STOP_PREP_SDA_LOW
    v112_expect [v112_sample STOP_PREP_SAMPLE] 0 STOP_PREP
    v112_write32 0x40000104 0x8 STOP_RELEASE_SCL
    v112_expect [v112_sample STOP_SCL_HIGH_SAMPLE] 4 STOP_SCL_HIGH
    v112_write32 0x40000100 0x9 STOP_RELEASE_SDA
    v112_expect [v112_sample FINAL_IDLE] 0xC FINAL_IDLE
    set ::v112_status [expr {$::v112_ack eq "ACK" ? "PASS_ADDRESS_ACK_STOP_IDLE" : "PASS_ADDRESS_NACK_STOP_IDLE"}]
} err]
if {$rc} {
    set ::v112_status "FAIL_OR_UNKNOWN"
    echo "V112_ERROR=$err"
    # Safe cleanup is limited to one best-effort release: both GPIO lines input/high-Z.
    if {$::v112_writes > 0} {catch {v112_write32 0x40000104 0x0 ERROR_RELEASE_LINES}}
}
set final_sb "UNKNOWN"
catch {set final_sb [v112_dread 0x38]}
set final_clk "UNKNOWN"
catch {set final_clk [v112_read32 0x4002180C FINAL_CLKEN]}
echo [format "V112_FINAL SBCS=%s CLKEN=%s" $final_sb $final_clk]
echo [format "V112_RESULT=%s ACK=%s TARGET_MMIO_WRITE_COUNT=%d HALT_COUNT=%d" $::v112_status $::v112_ack $::v112_writes $::v112_halts]
echo "V112_COMPLETE"
shutdown
