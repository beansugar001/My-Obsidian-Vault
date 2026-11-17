set ::v144_writes 0
set ::v144_halts 0
set ::v144_dir 0
set ::v144_release_needed 0

proc v144_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v144_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V144_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v144_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v144_dmi_read 0x38]
        echo [format "V144_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v144_read {addr label} {
    v144_sba_idle ${label}_PRE 1
    v144_dmi_write 0x38 0x20140404
    v144_sba_idle ${label}_READ_MODE 1
    v144_dmi_write 0x39 $addr
    v144_sba_idle ${label}_READ_DONE 50
    set value [v144_dmi_read 0x3C]
    v144_sba_idle ${label}_DATA_READ 1
    v144_dmi_write 0x38 0x20040404
    echo [format "V144_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v144_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v144_dmi_read 0x11]
    echo [format "V144_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v144_expect {addr expected label} {
    set got [v144_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v144_write {addr value label} {
    if {$::v144_writes >= 10} {error "WRITE_BUDGET"}
    switch -- $::v144_writes {
        0 {set allowed [expr {$addr == 0x4002180C && $value == 1}]}
        1 {set allowed [expr {$addr == 0x4000015C && $value == 0x300}]}
        2 {set allowed [expr {$addr == 0x40000158 && $value == 0xC}]}
        default {
            set allowed [expr {$addr == 0x40000104 &&
                ($value == 0 || $value == 4 || $value == 8 || $value == 12)}]
        }
    }
    if {!$allowed} {error "WRITE_DENIED"}
    v144_halted
    if {$::v144_writes == 0} {
        v144_expect 0x40021810 0 GPIO_CLOCK_PARK_RST
    } else {
        v144_expect 0x40000100 0 ${label}_PARK_ODR_LOW
    }
    v144_sba_idle ${label}_PRE 1
    v144_dmi_write 0x38 0x20040404
    v144_sba_idle ${label}_WRITE_MODE 1
    v144_dmi_write 0x39 $addr
    v144_sba_idle ${label}_ADDRESS 1
    incr ::v144_writes
    echo [format "V144_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v144_writes $label $addr $value [clock milliseconds]]
    v144_dmi_write 0x3C $value
    v144_sba_idle ${label}_WRITE_DONE 50
    v144_expect $addr $value ${label}_VERIFY
}

proc v144_direction {value label} {
    if {$value == $::v144_dir} {return}
    if {$value != 0} {set ::v144_release_needed 1}
    v144_write 0x40000104 $value $label
    set ::v144_dir $value
    set ::v144_release_needed [expr {$value != 0}]
}

proc v144_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v144_read 0x40000150 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v144_run {} {
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
    echo "V144_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v144_halts
        echo "V144_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v144_halted
    for {set i 0} {$i < 3} {incr i} {
        v144_expect 0x4002180C 0 CLKEN_COLD_$i
        v144_expect 0x40021810 0 RST_COLD_$i
    }
    v144_write 0x4002180C 1 GPIO_CLOCK
    foreach {addr label} {
        0x40000104 DIR 0x40000168 AFR1 0x40000100 ODR
        0x40000158 OSOD 0x4000015C PUPD
    } {
        v144_expect $addr 0 GPIOB_COLD_$label
    }
    v144_read 0x40000150 IDR_BEFORE_PULLUP
    v144_write 0x4000015C 0x300 GPIOB_PULLUP
    v144_write 0x40000158 0xC GPIOB_OPEN_DRAIN
    v144_expect 0x4002180C 1 ONLY_GPIO_CLOCK_ENABLED
    v144_expect 0x40021810 0 RESET_RELEASED
    v144_input_high 0xC BEFORE_PULSES
    foreach {line drive other} {SCL_1 4 8 SDA_1 8 4 SDA_2 8 4} {
        v144_direction $drive ${line}_LOW
        echo [format "V144_PULSE_LOW %s t_ms=%s" $line [clock milliseconds]]
        v144_input_high $other ${line}_OTHER_INPUT_HIGH
        sleep 300
        v144_direction 0 ${line}_RELEASE
        v144_input_high 0xC ${line}_BOTH_RELEASED
        echo [format "V144_PULSE_RELEASE %s t_ms=%s" $line [clock milliseconds]]
        sleep 300
    }
    v144_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    v144_expect 0x40000104 0 FINAL_INPUT_DIR
    return GPIO_PULSES_ISSUED
}

set rc [catch {v144_run} result]
if {$rc} {
    echo "V144_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v144_release_needed} {
        set released [catch {
            v144_expect 0x4002180C 1 RELEASE_CLOCK
            v144_expect 0x40000168 0 RELEASE_GPIO_AF
            set dir [v144_read 0x40000104 RELEASE_CURRENT_DIR]
            if {$dir & ~0xC} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v144_write 0x40000104 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V144_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V144_RESULT=$result HALTS=$::v144_halts WRITES=$::v144_writes"
echo "V144_COMPLETE"
shutdown

