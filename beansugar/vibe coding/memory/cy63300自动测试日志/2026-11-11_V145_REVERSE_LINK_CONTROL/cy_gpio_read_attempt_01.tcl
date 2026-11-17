proc v145_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v145_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V145_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v145_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v145_dmi_read 0x38]
        echo [format "V145_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v145_read {addr label} {
    v145_sba_idle ${label}_PRE 1
    v145_dmi_write 0x38 0x20140404
    v145_sba_idle ${label}_READ_MODE 1
    v145_dmi_write 0x39 $addr
    v145_sba_idle ${label}_READ_DONE 50
    set value [v145_dmi_read 0x3C]
    v145_sba_idle ${label}_DATA_READ 1
    v145_dmi_write 0x38 0x20040404
    echo [format "V145_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v145_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v145_dmi_read 0x11]
    echo [format "V145_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v145_expect {addr expected label} {
    set got [v145_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}


proc v145_inputs {} {
    v145_expect 0x4002180C 1 GPIO_CLOCK_ONLY
    v145_expect 0x40021810 0 RESET_CLEAR
    v145_expect 0x40000104 0 GPIOB_DIR_INPUT
    v145_expect 0x40000168 0 GPIOB_AFR_GPIO
    v145_expect 0x4000015C 0x300 GPIOB_PULLUP
}

proc v145_run {} {

    v145_inputs
    if {$::v145_phase eq "gate"} {
        for {set i 0} {$i < 3} {incr i} {
            set idr [v145_read 0x40000150 BASELINE_$i]
            if {($idr & 0xC) != 0xC} {error "BASELINE_NOT_IDLE"}
        }
    } elseif {$::v145_phase eq "observe"} {
        set deadline [expr {[clock milliseconds] + 22500}]
        set i 0
        while {[clock milliseconds] < $deadline} {
            set idr [v145_read 0x40000150 SAMPLE_$i]
            echo [format "V145_INPUT i=%d host_ms=%s idr=0x%08X masked=0x%X" $i [clock milliseconds] $idr [expr {$idr & 0xC}]]
            incr i
            sleep 80
        }
        v145_halted
        v145_inputs
    } else {
        error "UNKNOWN_PHASE"
    }
}

set ::v145_halts 0
set rc [catch {v145_run} reason]
if {$rc} {echo "V145_ERROR=$reason"}
echo "V145_COMPLETE phase=$::v145_phase rc=$rc halts=$::v145_halts target_writes=0"
shutdown
