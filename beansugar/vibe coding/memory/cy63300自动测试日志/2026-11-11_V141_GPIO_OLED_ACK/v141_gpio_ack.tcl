set ::v141_writes 0
set ::v141_halts 0
set ::v141_dir 0
set ::v141_release_needed 0

proc v141_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v141_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V141_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v141_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v141_dmi_read 0x38]
        echo [format "V141_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v141_read {addr label} {
    v141_sba_idle ${label}_PRE 1
    v141_dmi_write 0x38 0x20140404
    v141_sba_idle ${label}_READ_MODE 1
    v141_dmi_write 0x39 $addr
    v141_sba_idle ${label}_READ_DONE 50
    set value [v141_dmi_read 0x3C]
    v141_sba_idle ${label}_DATA_READ 1
    v141_dmi_write 0x38 0x20040404
    echo [format "V141_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v141_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v141_dmi_read 0x11]
    echo [format "V141_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v141_expect {addr expected label} {
    set got [v141_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v141_write {addr value label} {
    if {$::v141_writes >= 66} {error "WRITE_BUDGET"}
    switch -- $::v141_writes {
        0 {set allowed [expr {$addr == 0x4002180C && $value == 1}]}
        1 {set allowed [expr {$addr == 0x4000015C && $value == 0x300}]}
        2 {set allowed [expr {$addr == 0x40000158 && $value == 0xC}]}
        default {
            set allowed [expr {$addr == 0x40000104 &&
                ($value == 0 || $value == 4 || $value == 8 || $value == 12)}]
        }
    }
    if {!$allowed} {error "WRITE_DENIED"}
    v141_halted
    if {$::v141_writes == 0} {
        v141_expect 0x40021810 0 GPIO_CLOCK_PARK_RST
    } else {
        v141_expect 0x40000100 0 ${label}_PARK_ODR_LOW
    }
    v141_sba_idle ${label}_PRE 1
    v141_dmi_write 0x38 0x20040404
    v141_sba_idle ${label}_WRITE_MODE 1
    v141_dmi_write 0x39 $addr
    v141_sba_idle ${label}_ADDRESS 1
    incr ::v141_writes
    echo [format "V141_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v141_writes $label $addr $value [clock milliseconds]]
    v141_dmi_write 0x3C $value
    v141_sba_idle ${label}_WRITE_DONE 50
    v141_expect $addr $value ${label}_VERIFY
}

proc v141_direction {value label} {
    if {$value == $::v141_dir} {return}
    if {$value != 0} {set ::v141_release_needed 1}
    v141_write 0x40000104 $value $label
    set ::v141_dir $value
    set ::v141_release_needed [expr {$value != 0}]
}

proc v141_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v141_read 0x40000150 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v141_probe {addr} {
    set tag [format "A%02X" $addr]
    set byte [expr {$addr << 1}]
    v141_expect 0x40000104 0 ${tag}_IDLE_DIR
    v141_input_high 0xC ${tag}_IDLE
    echo [format "V141_FRAME_START addr=0x%02X byte=0x%02X t_ms=%s" $addr $byte [clock milliseconds]]
    v141_direction 8 ${tag}_START
    v141_input_high 4 ${tag}_START_SCL
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]
        set sda_dir [expr {$bit ? 0 : 8}]
        v141_direction [expr {4 | $sda_dir}] ${tag}_BIT_${i}_SETUP
        v141_direction $sda_dir ${tag}_BIT_${i}_RISE
        set mask [expr {$bit ? 0xC : 4}]
        set pins [v141_input_high $mask ${tag}_BIT_${i}_INPUT]
        echo [format "V141_BIT addr=0x%02X bit=%d data=%d idr=0x%X t_ms=%s" $addr $i $bit $pins [clock milliseconds]]
        v141_direction [expr {4 | $sda_dir}] ${tag}_BIT_${i}_FALL
    }
    v141_direction 4 ${tag}_ACK_RELEASE_SDA
    v141_direction 0 ${tag}_ACK_RELEASE_SCL
    v141_expect 0x40000104 0 ${tag}_ACK_BOTH_INPUT
    v141_input_high 4 ${tag}_ACK_SCL
    set lows 0
    for {set i 0} {$i < 3} {incr i} {
        set pins [v141_read 0x40000150 ${tag}_ACK_INPUT_$i]
        if {($pins & 4) == 0} {error "SCL_LOW_DURING_ACK:$tag"}
        if {($pins & 8) == 0} {incr lows}
        echo [format "V141_ACK_SAMPLE addr=0x%02X i=%d dir=0x0 idr=0x%X t_ms=%s" $addr $i $pins [clock milliseconds]]
    }
    set ack [lindex {NACK UNSTABLE UNSTABLE ACK} $lows]
    v141_direction 4 ${tag}_STOP_FALL_SCL
    v141_direction 12 ${tag}_STOP_PULL_SDA
    v141_direction 8 ${tag}_STOP_RELEASE_SCL
    v141_input_high 4 ${tag}_STOP_SCL_HIGH
    v141_direction 0 ${tag}_STOP_RELEASE_SDA
    v141_expect 0x40000104 0 ${tag}_STOP_DIR
    set idle [v141_input_high 0xC ${tag}_STOP_IDLE]
    echo [format "V141_FRAME_RESULT addr=0x%02X byte=0x%02X result=%s idle_idr=0x%X t_ms=%s" $addr $byte $ack $idle [clock milliseconds]]
    return $ack
}

proc v141_run {} {
    set init [capture {init}]
    echo $init
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0} $init]} {
        error "OPENOCD_INIT_ERROR"
    }
    if {[jtag names] ne "riscv.cpu" ||
        ![regexp -nocase {riscv.cpu tap/device found: 0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"}
    if {![regexp -nocase {Serial# = 07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {
        error "DAPLINK_SERIAL_MISMATCH"
    }
    set cpu [riscv.cpu curstate]
    echo "V141_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v141_halts
        echo "V141_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v141_halted
    for {set i 0} {$i < 3} {incr i} {
        v141_expect 0x4002180C 0 CLKEN_COLD_$i
        v141_expect 0x40021810 0 RST_COLD_$i
    }
    v141_write 0x4002180C 1 GPIO_CLOCK
    foreach {addr label} {
        0x40000104 DIR 0x40000168 AFR1 0x40000100 ODR
        0x40000158 OSOD 0x4000015C PUPD
    } {
        v141_expect $addr 0 GPIOB_COLD_$label
    }
    v141_read 0x40000150 IDR_BEFORE_PULLUP
    v141_write 0x4000015C 0x300 GPIOB_PULLUP
    v141_write 0x40000158 0xC GPIOB_OPEN_DRAIN
    v141_expect 0x4002180C 1 ONLY_GPIO_CLOCK_ENABLED
    v141_expect 0x40021810 0 RESET_RELEASED
    set first [v141_probe 0x3C]
    set second [v141_probe 0x3D]
    v141_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    if {$first eq "ACK" || $second eq "ACK"} {return ADDRESS_ACK_OBSERVED}
    if {$first eq "NACK" && $second eq "NACK"} {return BOTH_ADDRESS_NACK}
    return ADDRESS_ACK_UNSTABLE
}

set rc [catch {v141_run} result]
if {$rc} {
    echo "V141_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v141_release_needed} {
        set released [catch {
            v141_expect 0x4002180C 1 RELEASE_CLOCK
            v141_expect 0x40000168 0 RELEASE_GPIO_AF
            set dir [v141_read 0x40000104 RELEASE_CURRENT_DIR]
            if {$dir & ~0xC} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v141_write 0x40000104 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V141_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V141_RESULT=$result HALTS=$::v141_halts WRITES=$::v141_writes"
echo "V141_COMPLETE"
shutdown

