proc v147_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v147_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V147_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v147_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v147_dmi_read 0x38]
        echo [format "V147_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v147_read {addr label} {
    v147_sba_idle ${label}_PRE 1
    v147_dmi_write 0x38 0x20140404
    v147_sba_idle ${label}_READ_MODE 1
    v147_dmi_write 0x39 $addr
    v147_sba_idle ${label}_READ_DONE 50
    set value [v147_dmi_read 0x3C]
    v147_sba_idle ${label}_DATA_READ 1
    v147_dmi_write 0x38 0x20040404
    echo [format "V147_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v147_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v147_dmi_read 0x11]
    echo [format "V147_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v147_expect {addr expected label} {
    set got [v147_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}


proc v147_inputs {} {
    v147_expect 0x4002180C 1 GPIO_CLOCK_ONLY
    v147_expect 0x40021810 0 RESET_CLEAR
    v147_expect 0x40000104 0 GPIOB_DIR_INPUT
    v147_expect 0x40000168 0 GPIOB_AFR_GPIO
    v147_expect 0x4000015C 0x300 GPIOB_PULLUP
}

proc v147_run {} {
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
    echo "V147_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v147_halts
        echo "V147_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v147_halted
    if {$::v147_phase eq "gate"} {
        v147_inputs
        for {set i 0} {$i < 3} {incr i} {
            set idr [v147_read 0x40000150 BASELINE_$i]
            if {($idr & 0xC) != 0xC} {error "BASELINE_NOT_IDLE"}
        }
    } elseif {$::v147_phase eq "observe"} {
        v147_inputs
        set deadline [expr {[clock milliseconds] + 34500}]
        set i 0
        while {[clock milliseconds] < $deadline} {
            set idr [v147_read 0x40000150 SAMPLE_$i]
            echo [format "V147_INPUT i=%d host_ms=%s idr=0x%08X masked=0x%X" $i [clock milliseconds] $idr [expr {$idr & 0xC}]]
            incr i
            sleep 80
        }
        v147_halted
        v147_inputs
    } else {
        error "UNKNOWN_PHASE"
    }
}

set ::v147_halts 0
set ::v147_writes 0
set rc [catch {v147_run} reason]
if {$rc} {echo "V147_ERROR=$reason"}
echo "V147_COMPLETE phase=$::v147_phase rc=$rc halts=$::v147_halts target_writes=$::v147_writes"
shutdown
