set ::v151_writes 0
set ::v151_halts 0
set ::v151_dir 0
set ::v151_release_needed 0

proc v151_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v151_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V151_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v151_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v151_dmi_read 0x38]
        echo [format "V151_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v151_read {addr label} {
    v151_sba_idle ${label}_PRE 1
    v151_dmi_write 0x38 0x20140404
    v151_sba_idle ${label}_READ_MODE 1
    v151_dmi_write 0x39 $addr
    v151_sba_idle ${label}_READ_DONE 50
    set value [v151_dmi_read 0x3C]
    v151_sba_idle ${label}_DATA_READ 1
    v151_dmi_write 0x38 0x20040404
    echo [format "V151_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v151_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v151_dmi_read 0x11]
    echo [format "V151_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v151_expect {addr expected label} {
    set got [v151_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v151_write {addr value label} {
    if {$::v151_writes >= 8} {error "WRITE_BUDGET"}
    if {$::v151_writes == 0} {
        set allowed [expr {$addr == 0x40000258 && $value == 3}]
    } else {
        set allowed [expr {$addr == 0x40000204 && ($value == 0 || $value == 1 || $value == 2)}]
    }
    if {!$allowed} {error "WRITE_DENIED"}
    v151_halted
    v151_expect 0x40000200 0 ${label}_PARK_ODR_LOW
    v151_sba_idle ${label}_PRE 1
    v151_dmi_write 0x38 0x20040404
    v151_sba_idle ${label}_WRITE_MODE 1
    v151_dmi_write 0x39 $addr
    v151_sba_idle ${label}_ADDRESS 1
    incr ::v151_writes
    echo [format "V151_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v151_writes $label $addr $value [clock milliseconds]]
    v151_dmi_write 0x3C $value
    v151_sba_idle ${label}_WRITE_DONE 50
    v151_expect $addr $value ${label}_VERIFY
}

proc v151_direction {value label} {
    if {$value == $::v151_dir} {return}
    if {$value != 0} {set ::v151_release_needed 1}
    v151_write 0x40000204 $value $label
    set ::v151_dir $value
    set ::v151_release_needed [expr {$value != 0}]
}

proc v151_input_high {mask label} {
    for {set i 0} {$i < 3} {incr i} {
        set pins [v151_read 0x40000250 ${label}_$i]
        if {($pins & $mask) == $mask} {return $pins}
        sleep 2
    }
    error [format "INPUT_NOT_HIGH:%s mask=0x%X idr=0x%X" $label $mask $pins]
}

proc v151_run {} {
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
    echo "V151_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v151_halts
        echo "V151_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v151_halted
    for {set i 0} {$i < 3} {incr i} {
        v151_expect 0x4002180C 1 ONLY_GPIO_CLOCK
        v151_expect 0x40021810 0 RESET_RELEASED
    }
    foreach {addr label} {
        0x40000204 DIR 0x40000268 AFR1 0x4000026C AFR2
        0x40000200 ODR 0x40000258 OSOD 0x4000025C PUPD
    } {
        v151_expect $addr 0 GPIOC_BASE_$label
    }
    v151_input_high 0x3 IDLE_BEFORE_SETUP
    v151_write 0x40000258 0x3 GPIOC_OPEN_DRAIN
    v151_input_high 0x3 BEFORE_PULSES
    foreach {line drive other} {SCL_1 1 2 SDA_1 2 1 SDA_2 2 1} {
        v151_direction $drive ${line}_LOW
        echo [format "V151_PULSE_LOW %s t_ms=%s" $line [clock milliseconds]]
        v151_input_high $other ${line}_OTHER_INPUT_HIGH
        sleep 300
        v151_direction 0 ${line}_RELEASE
        v151_input_high 0x3 ${line}_BOTH_RELEASED
        echo [format "V151_PULSE_RELEASE %s t_ms=%s" $line [clock milliseconds]]
        sleep 300
    }
    v151_expect 0x4002180C 1 FINAL_I2C_CLOCK_OFF
    v151_expect 0x40000204 0 FINAL_INPUT_DIR
    return GPIO_PULSES_ISSUED
}

set rc [catch {v151_run} result]
if {$rc} {
    echo "V151_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
    if {$::v151_release_needed} {
        set released [catch {
            v151_expect 0x4002180C 1 RELEASE_CLOCK
            v151_expect 0x40000268 0 RELEASE_GPIO_AF
            set dir [v151_read 0x40000204 RELEASE_CURRENT_DIR]
            if {$dir & ~0x3} {error "RELEASE_OTHER_GPIO_OUTPUT"}
            if {$dir != 0} {v151_write 0x40000204 0 ERROR_RELEASE_BOTH_INPUT}
        } release_error]
        echo "V151_ERROR_RELEASE rc=$released result=$release_error"
    }
}
echo "V151_RESULT=$result HALTS=$::v151_halts WRITES=$::v151_writes"
echo "V151_COMPLETE"
shutdown

