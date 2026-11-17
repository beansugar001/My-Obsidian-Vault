proc v149_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v149_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V149_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v149_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v149_dmi_read 0x38]
        echo [format "V149_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v149_read {addr label} {
    v149_sba_idle ${label}_PRE 1
    v149_dmi_write 0x38 0x20140404
    v149_sba_idle ${label}_READ_MODE 1
    v149_dmi_write 0x39 $addr
    v149_sba_idle ${label}_READ_DONE 50
    set value [v149_dmi_read 0x3C]
    v149_sba_idle ${label}_DATA_READ 1
    v149_dmi_write 0x38 0x20040404
    echo [format "V149_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v149_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v149_dmi_read 0x11]
    echo [format "V149_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v149_expect {addr expected label} {
    set got [v149_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}


proc v149_inputs {} {
    v149_expect 0x4002180C 1 GPIO_CLOCK_ONLY
    v149_expect 0x40021810 0 RESET_CLEAR
    v149_expect 0x40000104 0 GPIOB_DIR_INPUT
    v149_expect 0x40000168 0 GPIOB_AFR_GPIO
    v149_expect 0x4000015C 0x300 GPIOB_PULLUP
}

proc v149_method {method round} {
    switch -- $method {
        direct {
            v149_read 0x40000150 DIRECT_PRIME_$round
            return [v149_read 0x40000150 DIRECT_REPEAT_$round]
        }
        parked {
            v149_expect 0x40000104 0 PARK_INPUT_DIR_$round
            return [v149_read 0x40000150 PARKED_IDR_$round]
        }
        native {
            v149_sba_idle NATIVE_PRE 1
            set raw [capture {mdw 0x40000150 1}]
            echo "V149_NATIVE_RAW round=$round <$raw>"
            if {![regexp -nocase {0x40000150:[ \t]+([0-9a-f]{8})} $raw -> hex]} {
                error "NATIVE_PARSE_ERROR"
            }
            scan $hex %x value
            v149_sba_idle NATIVE_POST 50
            v149_dmi_write 0x38 0x20040404
            v149_sba_idle NATIVE_MODE_IDLE 1
            return $value
        }
        default {error "UNKNOWN_READ_METHOD"}
    }
}

proc v149_run {} {
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
    echo "V149_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v149_halts
        echo "V149_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v149_halted
    v149_inputs
    if {$::v149_phase eq "gate"} {
        for {set i 0} {$i < 3} {incr i} {
            set idr [v149_read 0x40000150 BASELINE_$i]
            if {($idr & 0xC) != 0xC} {error "BASELINE_NOT_IDLE"}
        }
    } elseif {$::v149_phase eq "observe"} {
        set deadline [expr {[clock milliseconds] + 34500}]
        set i 0
        while {[clock milliseconds] < $deadline} {
            v149_halted
            set order [lindex {{direct parked native} {parked native direct} {native direct parked}} [expr {$i % 3}]]
            foreach method $order {
                set value [v149_method $method $i]
                echo [format "V149_SAMPLE method=%s round=%d host_ms=%s idr=0x%08X masked=0x%X" $method $i [clock milliseconds] $value [expr {$value & 0xC}]]
            }
            incr i
        }
        v149_halted
        v149_inputs
    } else {
        error "UNKNOWN_PHASE"
    }
}

set ::v149_halts 0
set rc [catch {v149_run} reason]
if {$rc} {echo "V149_ERROR=$reason"}
echo "V149_COMPLETE phase=$::v149_phase rc=$rc halts=$::v149_halts target_writes=0"
shutdown
