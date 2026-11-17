set ::v152_writes 0
set ::v152_halts 0
set ::v152_dir 0
set ::v152_release_needed 0

proc v152_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v152_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V152_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v152_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v152_dmi_read 0x38]
        echo [format "V152_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v152_read {addr label} {
    v152_sba_idle ${label}_PRE 1
    v152_dmi_write 0x38 0x20140404
    v152_sba_idle ${label}_READ_MODE 1
    v152_dmi_write 0x39 $addr
    v152_sba_idle ${label}_READ_DONE 50
    set value [v152_dmi_read 0x3C]
    v152_sba_idle ${label}_DATA_READ 1
    v152_dmi_write 0x38 0x20040404
    echo [format "V152_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v152_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v152_dmi_read 0x11]
    echo [format "V152_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v152_expect {addr expected label} {
    set got [v152_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v152_write {addr value label} {
    if {$::v152_writes >= 32} {error "WRITE_BUDGET"}
    if {$addr != 0x40000204 || ($value != 0 && $value != 1 && $value != 2 && $value != 3)} {
        error "WRITE_DENIED"
    }
    v152_halted
    v152_expect 0x40000200 0 ${label}_PARK_ODR_LOW
    v152_sba_idle ${label}_PRE 1
    v152_dmi_write 0x38 0x20040404
    v152_sba_idle ${label}_WRITE_MODE 1
    v152_dmi_write 0x39 $addr
    v152_sba_idle ${label}_ADDRESS 1
    incr ::v152_writes
    echo [format "V152_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v152_writes $label $addr $value [clock milliseconds]]
    v152_dmi_write 0x3C $value
    v152_sba_idle ${label}_WRITE_DONE 50
    v152_expect $addr $value ${label}_VERIFY
}

proc v152_direction {value label} {
    if {$value == $::v152_dir} {return}
    if {$value != 0} {set ::v152_release_needed 1}
    v152_write 0x40000204 $value $label
    set ::v152_dir $value
    set ::v152_release_needed [expr {$value != 0}]
}

proc v152_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v152_read 0x40000250 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v152_probe {addr} {
    set tag [format "A%02X" $addr]
    set byte [expr {$addr << 1}]
    v152_expect 0x40000204 0 ${tag}_IDLE_DIR
    v152_input_high 0x3 ${tag}_IDLE
    echo [format "V152_FRAME_START addr=0x%02X byte=0x%02X t_ms=%s" $addr $byte [clock milliseconds]]
    v152_direction 2 ${tag}_START
    v152_input_high 1 ${tag}_START_SCL
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]
        set sda_dir [expr {$bit ? 0 : 2}]
        v152_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_SETUP
        v152_direction $sda_dir ${tag}_BIT_${i}_RISE
        set mask [expr {$bit ? 0x3 : 1}]
        set pins [v152_input_high $mask ${tag}_BIT_${i}_INPUT]
        echo [format "V152_BIT addr=0x%02X bit=%d data=%d idr=0x%X t_ms=%s" $addr $i $bit $pins [clock milliseconds]]
        v152_direction [expr {1 | $sda_dir}] ${tag}_BIT_${i}_FALL
    }
    v152_direction 1 ${tag}_ACK_RELEASE_SDA
    v152_direction 0 ${tag}_ACK_RELEASE_SCL
    v152_expect 0x40000204 0 ${tag}_ACK_BOTH_INPUT
    v152_input_high 1 ${tag}_ACK_SCL
    set lows 0
    for {set i 0} {$i < 3} {incr i} {
        set pins [v152_read 0x40000250 ${tag}_ACK_INPUT_$i]
        if {($pins & 1) == 0} {error "SCL_LOW_DURING_ACK:$tag"}
        if {($pins & 2) == 0} {incr lows}
        echo [format "V152_ACK_SAMPLE addr=0x%02X i=%d dir=0x0 idr=0x%X t_ms=%s" $addr $i $pins [clock milliseconds]]
    }
    set ack [lindex {NACK UNSTABLE UNSTABLE ACK} $lows]
    v152_direction 1 ${tag}_STOP_FALL_SCL
    v152_direction 3 ${tag}_STOP_PULL_SDA
    v152_direction 2 ${tag}_STOP_RELEASE_SCL
    v152_input_high 1 ${tag}_STOP_SCL_HIGH
    v152_direction 0 ${tag}_STOP_RELEASE_SDA
    v152_expect 0x40000204 0 ${tag}_STOP_DIR
    set idle [v152_input_high 0x3 ${tag}_STOP_IDLE]
    echo [format "V152_FRAME_RESULT addr=0x%02X byte=0x%02X result=%s idle_idr=0x%X t_ms=%s" $addr $byte $ack $idle [clock milliseconds]]
    return $ack
}

proc v152_run {} {
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
    echo "V152_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v152_halts
        echo "V152_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v152_halted
    for {set i 0} {$i < 3} {incr i} {
        v152_expect 0x4002180C 1 ONLY_GPIO_CLOCK
        v152_expect 0x40021810 0 RESET_RELEASED
    }
    foreach {addr label} {
        0x40000204 DIR 0x40000268 AFR1 0x4000026C AFR2
        0x40000200 ODR 0x4000025C PUPD
    } {
        v152_expect $addr 0 GPIOC_BASE_$label
    }
    v152_expect 0x40000258 3 OPEN_DRAIN_BOTH
    set ack [v152_probe 0x3C]
    v152_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    v152_expect 0x40000204 0 FINAL_BOTH_INPUT
    return ADDRESS_$ack
}

set rc [catch {v152_run} result]
if {$rc} {
    echo "V152_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v152_release_needed} {
        set released [catch {
            v152_expect 0x4002180C 1 RELEASE_CLOCK
            v152_expect 0x40000268 0 RELEASE_GPIO_AF
            set dir [v152_read 0x40000204 RELEASE_CURRENT_DIR]
            if {$dir & ~0x3} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v152_write 0x40000204 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V152_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V152_RESULT=$result HALTS=$::v152_halts WRITES=$::v152_writes"
echo "V152_COMPLETE"
shutdown

