# V109-PWR: one post-power-cycle read-only snapshot. No target MMIO writes.
set ::v109_status "INCOMPLETE_OR_UNKNOWN"
set ::v109_target_mmio_write_count 0
set ::v109_halt_request_count 0
set ::v109_probe_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
set ::v109_gpio_status "NOT_REACHED"
set ::v109_i2c_status "NOT_REACHED"

proc v109_dread {reg} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> raw]} {
        error "V109_DMI_READ_PARSE_FAIL reg=[format 0x%X $reg] output=<$out>"
    }
    scan $raw %x value
    return [expr {$value & 0xffffffff}]
}
proc v109_dwrite {reg value label} {
    echo [format "V109_DMI_CONTROL_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]]
}
proc v109_sb_status {label} {
    set v [v109_dread 0x38]
    echo [format "V109_SBCS label=%s value=0x%08X" $label $v]
    if {$v & 0x00607000} { error "V109_SBA_BUSY_OR_ERROR label=$label value=[format 0x%08X $v]" }
    return $v
}
proc v109_read {addr label} {
    v109_sb_status "${label}_BEFORE"
    v109_dwrite 0x38 0x20140404 "${label}_SBA_READ_MODE"
    v109_sb_status "${label}_MODE_SET"
    v109_dwrite 0x39 $addr "${label}_SBADDRESS0"
    set value [v109_dread 0x3c]
    v109_sb_status "${label}_AFTER"
    echo [format "V109_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}
proc v109_read_triplet {addr label} {
    set values {}
    for {set i 1} {$i <= 3} {incr i} {
        lappend values [v109_read $addr "${label}_${i}"]
        sleep 10
    }
    set stable 1
    if {[lindex $values 0] != [lindex $values 1] || [lindex $values 1] != [lindex $values 2]} { set stable 0 }
    echo [format "V109_TRIPLET label=%s values=%08X,%08X,%08X stable=%d" $label [lindex $values 0] [lindex $values 1] [lindex $values 2] $stable]
    if {!$stable} { error "V109_UNSTABLE_TRIPLET label=$label" }
    return [lindex $values 0]
}

set rc [catch {
    set initlog [capture {init}]
    echo "V109_INIT_BEGIN"; echo $initlog; echo "V109_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $initlog]} { error "V109_JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu"} { error "V109_TAP_NOT_UNIQUE names=[jtag names]" }
    if {![regexp -nocase {0x1e200a6f} $initlog]} { error "V109_IDCODE_MISSING_OR_WRONG" }
    if {![regexp -- $::v109_probe_serial $initlog]} { error "V109_PROBE_SERIAL_MISMATCH" }

    set cpu [riscv.cpu curstate]
    echo "V109_CPU_INITIAL_STATE=$cpu"
    if {$cpu eq "running"} {
        set haltlog [capture {halt 2000}]
        incr ::v109_halt_request_count
        echo "V109_HALT_OUTPUT_BEGIN"; echo $haltlog; echo "V109_HALT_OUTPUT_END"
        set cpu [riscv.cpu curstate]
    }
    echo "V109_CPU_FINAL_STATE=$cpu"
    if {$cpu ne "halted"} { error "V109_CPU_NOT_HALTED" }

    set dm [v109_dread 0x11]
    echo [format "V109_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "V109_DMSTATUS_NOT_HALTED" }
    v109_sb_status PREFLIGHT

    set clk [v109_read_triplet 0x4002180c PERI_CLKEN]
    set rst [v109_read_triplet 0x40021810 PERI_RST]
    echo [format "V109_CLOCK_RESET_BASELINE CLKEN=0x%08X RST=0x%08X" $clk $rst]

    # GPIOB internal registers are meaningful only if GPIO clock is on and GPIO reset is released.
    if {($clk & 1) != 0 && ($rst & 1) == 0} {
        foreach {label addr} {GPIOB_ODR 0x40000100 GPIOB_DIR 0x40000104 GPIOB_IDR 0x40000150 GPIOB_OSOD 0x40000158 GPIOB_PUPD 0x4000015c GPIOB_AFR1 0x40000168 GPIOB_AFR2 0x4000016c} {
            v109_read $addr $label
        }
        set ::v109_gpio_status "READ"
    } else {
        set ::v109_gpio_status "SKIPPED_GPIO_CLOCK_OFF_OR_RESET_ASSERTED"
        echo "V109_GPIO_SNAPSHOT_SKIPPED reason=$::v109_gpio_status"
    }

    # Never touch the I2C register window while its clock is off or reset is asserted.
    if {($clk & 0x20) != 0 && ($rst & 0x20) == 0} {
        foreach {label addr} {I2C_MODULE_CTRL 0x40002800 I2C_FIFO_STA 0x4000280c I2C_STA 0x4000283c} {
            v109_read $addr $label
        }
        set ::v109_i2c_status "READ_CLOCK_ON_RESET_RELEASED"
    } else {
        set ::v109_i2c_status "SKIPPED_CLOCK_OFF_OR_RESET_ASSERTED"
        echo "V109_I2C_SNAPSHOT_SKIPPED reason=$::v109_i2c_status"
    }
    set ::v109_status "PASS_READ_ONLY_POST_POWER_SNAPSHOT"
} err]
if {$rc} { set ::v109_status "FAIL_OR_UNKNOWN"; echo "V109_ERROR=$err" }
set sb_rc [catch {v109_sb_status FINAL} sb_val]
echo [format "V109_FINAL_SBCS rc=%d value=%s" $sb_rc $sb_val]
set dm_rc [catch {v109_dread 0x11} dm_val]
echo [format "V109_FINAL_DMSTATUS rc=%d value=%s" $dm_rc $dm_val]
echo [format "V109_RESULT=%s HALT_REQUESTS=%d TARGET_MMIO_WRITE_COUNT=%d GPIO=%s I2C=%s" $::v109_status $::v109_halt_request_count $::v109_target_mmio_write_count $::v109_gpio_status $::v109_i2c_status]
echo "V109_COMPLETE"
shutdown
