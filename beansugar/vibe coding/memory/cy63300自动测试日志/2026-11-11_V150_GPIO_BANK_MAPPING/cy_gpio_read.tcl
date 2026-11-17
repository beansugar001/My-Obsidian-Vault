proc v150_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v150_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V150_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v150_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v150_dmi_read 0x38]
        echo [format "V150_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v150_read {addr label} {
    v150_sba_idle ${label}_PRE 1
    v150_dmi_write 0x38 0x20140404
    v150_sba_idle ${label}_READ_MODE 1
    v150_dmi_write 0x39 $addr
    v150_sba_idle ${label}_READ_DONE 50
    set value [v150_dmi_read 0x3C]
    v150_sba_idle ${label}_DATA_READ 1
    v150_dmi_write 0x38 0x20040404
    echo [format "V150_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v150_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v150_dmi_read 0x11]
    echo [format "V150_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v150_expect {addr expected label} {
    set got [v150_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}


proc v150_inputs {} {
    v150_expect 0x4002180C 1 GPIO_CLOCK_ONLY
    v150_expect 0x40021810 0 RESET_CLEAR
    v150_expect 0x40000104 0 GPIOB_DIR_INPUT
    v150_expect 0x40000168 0 GPIOB_AFR_GPIO
    v150_expect 0x4000015C 0x300 GPIOB_PULLUP
}

proc v150_snapshot {label} {
    foreach {bank base} {A 0x40000000 B 0x40000100 C 0x40000200} {
        foreach {offset field} {0x04 DIR 0x5C PUPD 0x68 AFR1 0x6C AFR2} {
            set value [v150_read [expr {$base + $offset}] ${label}_${bank}_${field}]
            echo [format "V150_CONFIG snapshot=%s bank=%s field=%s value=0x%08X" $label $bank $field $value]
        }
    }
}

proc v150_run {} {
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
    echo "V150_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v150_halts
        echo "V150_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v150_halted
    v150_inputs
    v150_snapshot START
    if {$::v150_phase eq "gate"} {
        for {set i 0} {$i < 3} {incr i} {
            set idr [v150_read 0x40000150 BASELINE_$i]
            if {($idr & 0xC) != 0xC} {error "BASELINE_NOT_IDLE"}
        }
    } elseif {$::v150_phase eq "observe"} {
        set deadline [expr {[clock milliseconds] + 34500}]
        set i 0
        while {[clock milliseconds] < $deadline} {
            v150_halted
            set order [lindex {{A B C} {B C A} {C A B}} [expr {$i % 3}]]
            foreach bank $order {
                switch -- $bank {
                    A {set addr 0x40000050}
                    B {set addr 0x40000150}
                    C {set addr 0x40000250}
                }
                set value [v150_read $addr BANK_${bank}_$i]
                echo [format "V150_BANK_SAMPLE bank=%s round=%d host_ms=%s idr=0x%08X" $bank $i [clock milliseconds] $value]
            }
            incr i
        }
        v150_halted
        v150_inputs
        v150_snapshot END
    } else {
        error "UNKNOWN_PHASE"
    }
}

set ::v150_halts 0
set rc [catch {v150_run} reason]
if {$rc} {echo "V150_ERROR=$reason"}
echo "V150_COMPLETE phase=$::v150_phase rc=$rc halts=$::v150_halts target_writes=0"
shutdown
