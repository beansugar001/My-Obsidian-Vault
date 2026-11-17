proc v146_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v146_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V146_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v146_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v146_dmi_read 0x38]
        echo [format "V146_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v146_read {addr label} {
    v146_sba_idle ${label}_PRE 1
    v146_dmi_write 0x38 0x20140404
    v146_sba_idle ${label}_READ_MODE 1
    v146_dmi_write 0x39 $addr
    v146_sba_idle ${label}_READ_DONE 50
    set value [v146_dmi_read 0x3C]
    v146_sba_idle ${label}_DATA_READ 1
    v146_dmi_write 0x38 0x20040404
    echo [format "V146_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v146_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v146_dmi_read 0x11]
    echo [format "V146_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v146_expect {addr expected label} {
    set got [v146_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}


proc v146_inputs {} {
    v146_expect 0x4002180C 1 GPIO_CLOCK_ONLY
    v146_expect 0x40021810 0 RESET_CLEAR
    v146_expect 0x40000104 0 GPIOB_DIR_INPUT
    v146_expect 0x40000168 0 GPIOB_AFR_GPIO
    v146_expect 0x4000015C 0x300 GPIOB_PULLUP
}

proc v146_configure {addr value label} {
    if {$::v146_phase ne "gate" || $::v146_writes >= 2 ||
        !(($addr == 0x4002180C && $value == 1) || ($addr == 0x4000015C && $value == 0x300))} {
        error "WRITE_DENIED"
    }
    v146_halted
    if {$addr == 0x4002180C} {
        v146_expect 0x40021810 0 CLOCK_PARK_RST
    } else {
        v146_expect 0x40000100 0 PULLUP_PARK_ODR
    }
    v146_sba_idle ${label}_PRE 1
    v146_dmi_write 0x38 0x20040404
    v146_sba_idle ${label}_MODE 1
    v146_dmi_write 0x39 $addr
    v146_sba_idle ${label}_ADDRESS 1
    incr ::v146_writes
    echo [format "V146_TARGET_WRITE %s addr=0x%08X value=0x%08X" $label $addr $value]
    v146_dmi_write 0x3C $value
    v146_sba_idle ${label}_DONE 50
    v146_expect $addr $value ${label}_VERIFY
}

proc v146_prepare_inputs {} {
    set clock [v146_read 0x4002180C INITIAL_CLOCK]
    v146_expect 0x4002180C $clock INITIAL_CLOCK_AGAIN
    v146_expect 0x40021810 0 INITIAL_RST
    if {$clock == 0} {
        v146_configure 0x4002180C 1 GPIO_CLOCK_ONLY
    } elseif {$clock != 1} {
        error "I2C_CLOCK_OR_OTHER_CLOCK_ENABLED"
    }
    v146_expect 0x40000104 0 GPIO_DIR_BEFORE
    v146_expect 0x40000168 0 GPIO_AFR_BEFORE
    set pupd [v146_read 0x4000015C GPIO_PULLUP_BEFORE]
    if {$pupd == 0} {v146_configure 0x4000015C 0x300 GPIO_PULLUP}
    v146_inputs
}

proc v146_run {} {
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
    echo "V146_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v146_halts
        echo "V146_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v146_halted
    if {$::v146_phase eq "gate"} {
        v146_prepare_inputs
        for {set i 0} {$i < 3} {incr i} {
            set idr [v146_read 0x40000150 BASELINE_$i]
            if {($idr & 0xC) != 0xC} {error "BASELINE_NOT_IDLE"}
        }
    } elseif {$::v146_phase eq "observe"} {
        v146_inputs
        set deadline [expr {[clock milliseconds] + 34500}]
        set i 0
        while {[clock milliseconds] < $deadline} {
            set idr [v146_read 0x40000150 SAMPLE_$i]
            echo [format "V146_INPUT i=%d host_ms=%s idr=0x%08X masked=0x%X" $i [clock milliseconds] $idr [expr {$idr & 0xC}]]
            incr i
            sleep 80
        }
        v146_halted
        v146_inputs
    } else {
        error "UNKNOWN_PHASE"
    }
}

set ::v146_halts 0
set ::v146_writes 0
set rc [catch {v146_run} reason]
if {$rc} {echo "V146_ERROR=$reason"}
echo "V146_COMPLETE phase=$::v146_phase rc=$rc halts=$::v146_halts target_writes=$::v146_writes"
shutdown
