set ::v154_writes 0
set ::v154_halts 0
set ::v154_dir 0
set ::v154_release_needed 0

proc v154_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v154_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V154_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v154_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v154_dmi_read 0x38]
        echo [format "V154_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v154_read {addr label} {
    v154_sba_idle ${label}_PRE 1
    v154_dmi_write 0x38 0x20140404
    v154_sba_idle ${label}_READ_MODE 1
    v154_dmi_write 0x39 $addr
    v154_sba_idle ${label}_READ_DONE 50
    set value [v154_dmi_read 0x3C]
    v154_sba_idle ${label}_DATA_READ 1
    v154_dmi_write 0x38 0x20040404
    echo [format "V154_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v154_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v154_dmi_read 0x11]
    echo [format "V154_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v154_expect {addr expected label} {
    set got [v154_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v154_write {addr value label} {
    if {$::v154_writes >= 210} {error "WRITE_BUDGET"}
    if {$addr != 0x40000204 || ($value != 0 && $value != 1 && $value != 2 && $value != 3)} {
        error "WRITE_DENIED"
    }
    v154_halted
    v154_expect 0x40000200 0 ${label}_PARK_ODR_LOW
    v154_sba_idle ${label}_PRE 1
    v154_dmi_write 0x38 0x20040404
    v154_sba_idle ${label}_WRITE_MODE 1
    v154_dmi_write 0x39 $addr
    v154_sba_idle ${label}_ADDRESS 1
    incr ::v154_writes
    echo [format "V154_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v154_writes $label $addr $value [clock milliseconds]]
    v154_dmi_write 0x3C $value
    v154_sba_idle ${label}_WRITE_DONE 50
    v154_expect $addr $value ${label}_VERIFY
}

proc v154_direction {value label} {
    if {$value == $::v154_dir} {return}
    if {$value != 0} {set ::v154_release_needed 1}
    v154_write 0x40000204 $value $label
    set ::v154_dir $value
    set ::v154_release_needed [expr {$value != 0}]
}

proc v154_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v154_read 0x40000250 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v154_send_byte {byte index} {
    set tag [format "BYTE%d_%02X" $index $byte]
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]
        set sda_dir [expr {$bit ? 0 : 2}]
        v154_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_SETUP
        v154_direction $sda_dir ${tag}_BIT_${i}_RISE
        set mask [expr {$bit ? 0x3 : 1}]
        set pins [v154_input_high $mask ${tag}_BIT_${i}_INPUT]
        echo [format "V154_BIT byte=0x%02X bit=%d data=%d idr=0x%X t_ms=%s" $byte $i $bit $pins [clock milliseconds]]
        v154_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_FALL
    }
    v154_direction 1 ${tag}_ACK_RELEASE_SDA
    v154_direction 0 ${tag}_ACK_RELEASE_SCL
    v154_expect 0x40000204 0 ${tag}_ACK_BOTH_INPUT
    v154_input_high 1 ${tag}_ACK_SCL
    set lows 0
    for {set i 0} {$i < 3} {incr i} {
        set pins [v154_read 0x40000250 ${tag}_ACK_INPUT_$i]
        if {($pins & 1) == 0} {error "SCL_LOW_DURING_ACK:$tag"}
        if {($pins & 2) == 0} {incr lows}
        echo [format "V154_ACK_SAMPLE byte=0x%02X index=%d i=%d dir=0x0 idr=0x%X t_ms=%s" $byte $index $i $pins [clock milliseconds]]
    }
    set ack [lindex {NACK UNSTABLE UNSTABLE ACK} $lows]
    v154_direction 1 ${tag}_ACK_FALL_SCL
    echo [format "V154_BYTE_RESULT index=%d byte=0x%02X result=%s" $index $byte $ack]
    return $ack
}

proc v154_stop {} {
    set tag OLED
    v154_direction 1 ${tag}_STOP_FALL_SCL
    v154_direction 3 ${tag}_STOP_PULL_SDA
    v154_direction 2 ${tag}_STOP_RELEASE_SCL
    v154_input_high 1 ${tag}_STOP_SCL_HIGH
    v154_direction 0 ${tag}_STOP_RELEASE_SDA
    v154_expect 0x40000204 0 ${tag}_STOP_DIR
    set idle [v154_input_high 0x3 ${tag}_STOP_IDLE]
    echo [format "V154_STOP idle_idr=0x%X t_ms=%s" $idle [clock milliseconds]]
}

proc v154_frame {} {
    v154_expect 0x40000204 0 IDLE_DIR
    v154_input_high 3 IDLE
    v154_direction 2 OLED_START
    v154_input_high 1 START_SCL_HIGH
    set index 0
    foreach byte {0x78 0x00 0xA6 0x8D 0x14 0xA5 0xAF} {
        set ack [v154_send_byte $byte $index]
        if {$ack ne "ACK"} {
            v154_stop
            return BYTE_${index}_$ack
        }
        incr index
    }
    v154_stop
    return DISPLAY_ON_ALL_ACK
}

proc v154_run {} {
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
    echo "V154_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v154_halts
        echo "V154_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v154_halted
    for {set i 0} {$i < 3} {incr i} {
        v154_expect 0x4002180C 1 ONLY_GPIO_CLOCK
        v154_expect 0x40021810 0 RESET_RELEASED
    }
    foreach {addr label} {
        0x40000204 DIR 0x40000268 AFR1 0x4000026C AFR2
        0x40000200 ODR 0x4000025C PUPD
    } {
        v154_expect $addr 0 GPIOC_BASE_$label
    }
    v154_expect 0x40000258 3 OPEN_DRAIN_BOTH
    set result [v154_frame]
    v154_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    v154_expect 0x40000204 0 FINAL_BOTH_INPUT
    return $result
}

set rc [catch {v154_run} result]
if {$rc} {
    echo "V154_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v154_release_needed} {
        set released [catch {
            v154_expect 0x4002180C 1 RELEASE_CLOCK
            v154_expect 0x40000268 0 RELEASE_GPIO_AF
            set dir [v154_read 0x40000204 RELEASE_CURRENT_DIR]
            if {$dir & ~0x3} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v154_write 0x40000204 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V154_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V154_RESULT=$result HALTS=$::v154_halts WRITES=$::v154_writes"
echo "V154_COMPLETE"
shutdown

