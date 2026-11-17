set ::v153_writes 0
set ::v153_halts 0
set ::v153_dir 0
set ::v153_release_needed 0

proc v153_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v153_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V153_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v153_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v153_dmi_read 0x38]
        echo [format "V153_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v153_read {addr label} {
    v153_sba_idle ${label}_PRE 1
    v153_dmi_write 0x38 0x20140404
    v153_sba_idle ${label}_READ_MODE 1
    v153_dmi_write 0x39 $addr
    v153_sba_idle ${label}_READ_DONE 50
    set value [v153_dmi_read 0x3C]
    v153_sba_idle ${label}_DATA_READ 1
    v153_dmi_write 0x38 0x20040404
    echo [format "V153_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v153_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v153_dmi_read 0x11]
    echo [format "V153_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v153_expect {addr expected label} {
    set got [v153_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v153_write {addr value label} {
    if {$::v153_writes >= 90} {error "WRITE_BUDGET"}
    if {$addr != 0x40000204 || ($value != 0 && $value != 1 && $value != 2 && $value != 3)} {
        error "WRITE_DENIED"
    }
    v153_halted
    v153_expect 0x40000200 0 ${label}_PARK_ODR_LOW
    v153_sba_idle ${label}_PRE 1
    v153_dmi_write 0x38 0x20040404
    v153_sba_idle ${label}_WRITE_MODE 1
    v153_dmi_write 0x39 $addr
    v153_sba_idle ${label}_ADDRESS 1
    incr ::v153_writes
    echo [format "V153_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v153_writes $label $addr $value [clock milliseconds]]
    v153_dmi_write 0x3C $value
    v153_sba_idle ${label}_WRITE_DONE 50
    v153_expect $addr $value ${label}_VERIFY
}

proc v153_direction {value label} {
    if {$value == $::v153_dir} {return}
    if {$value != 0} {set ::v153_release_needed 1}
    v153_write 0x40000204 $value $label
    set ::v153_dir $value
    set ::v153_release_needed [expr {$value != 0}]
}

proc v153_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v153_read 0x40000250 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v153_send_byte {byte index} {
    set tag [format "BYTE%d_%02X" $index $byte]
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]
        set sda_dir [expr {$bit ? 0 : 2}]
        v153_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_SETUP
        v153_direction $sda_dir ${tag}_BIT_${i}_RISE
        set mask [expr {$bit ? 0x3 : 1}]
        set pins [v153_input_high $mask ${tag}_BIT_${i}_INPUT]
        echo [format "V153_BIT byte=0x%02X bit=%d data=%d idr=0x%X t_ms=%s" $byte $i $bit $pins [clock milliseconds]]
        v153_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_FALL
    }
    v153_direction 1 ${tag}_ACK_RELEASE_SDA
    v153_direction 0 ${tag}_ACK_RELEASE_SCL
    v153_expect 0x40000204 0 ${tag}_ACK_BOTH_INPUT
    v153_input_high 1 ${tag}_ACK_SCL
    set lows 0
    for {set i 0} {$i < 3} {incr i} {
        set pins [v153_read 0x40000250 ${tag}_ACK_INPUT_$i]
        if {($pins & 1) == 0} {error "SCL_LOW_DURING_ACK:$tag"}
        if {($pins & 2) == 0} {incr lows}
        echo [format "V153_ACK_SAMPLE byte=0x%02X index=%d i=%d dir=0x0 idr=0x%X t_ms=%s" $byte $index $i $pins [clock milliseconds]]
    }
    set ack [lindex {NACK UNSTABLE UNSTABLE ACK} $lows]
    v153_direction 1 ${tag}_ACK_FALL_SCL
    echo [format "V153_BYTE_RESULT index=%d byte=0x%02X result=%s" $index $byte $ack]
    return $ack
}

proc v153_stop {} {
    set tag OLED
    v153_direction 1 ${tag}_STOP_FALL_SCL
    v153_direction 3 ${tag}_STOP_PULL_SDA
    v153_direction 2 ${tag}_STOP_RELEASE_SCL
    v153_input_high 1 ${tag}_STOP_SCL_HIGH
    v153_direction 0 ${tag}_STOP_RELEASE_SDA
    v153_expect 0x40000204 0 ${tag}_STOP_DIR
    set idle [v153_input_high 0x3 ${tag}_STOP_IDLE]
    echo [format "V153_STOP idle_idr=0x%X t_ms=%s" $idle [clock milliseconds]]
}

proc v153_frame {} {
    v153_expect 0x40000204 0 IDLE_DIR
    v153_input_high 3 IDLE
    v153_direction 2 OLED_START
    v153_input_high 1 START_SCL_HIGH
    set index 0
    foreach byte {0x78 0x00 0xA7} {
        set ack [v153_send_byte $byte $index]
        if {$ack ne "ACK"} {
            v153_stop
            return BYTE_${index}_$ack
        }
        incr index
    }
    v153_stop
    return INVERT_ALL_ACK
}

proc v153_run {} {
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
    echo "V153_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v153_halts
        echo "V153_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v153_halted
    for {set i 0} {$i < 3} {incr i} {
        v153_expect 0x4002180C 1 ONLY_GPIO_CLOCK
        v153_expect 0x40021810 0 RESET_RELEASED
    }
    foreach {addr label} {
        0x40000204 DIR 0x40000268 AFR1 0x4000026C AFR2
        0x40000200 ODR 0x4000025C PUPD
    } {
        v153_expect $addr 0 GPIOC_BASE_$label
    }
    v153_expect 0x40000258 3 OPEN_DRAIN_BOTH
    set result [v153_frame]
    v153_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    v153_expect 0x40000204 0 FINAL_BOTH_INPUT
    return $result
}

set rc [catch {v153_run} result]
if {$rc} {
    echo "V153_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v153_release_needed} {
        set released [catch {
            v153_expect 0x4002180C 1 RELEASE_CLOCK
            v153_expect 0x40000268 0 RELEASE_GPIO_AF
            set dir [v153_read 0x40000204 RELEASE_CURRENT_DIR]
            if {$dir & ~0x3} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v153_write 0x40000204 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V153_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V153_RESULT=$result HALTS=$::v153_halts WRITES=$::v153_writes"
echo "V153_COMPLETE"
shutdown

