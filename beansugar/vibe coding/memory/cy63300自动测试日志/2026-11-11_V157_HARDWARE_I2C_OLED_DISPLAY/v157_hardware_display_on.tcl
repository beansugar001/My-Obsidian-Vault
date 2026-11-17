set ::v157_writes 0
set ::v157_halts 0
set ::v157_stop_allowed 0
set ::v157_allowed {}

proc v157_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v157_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V157_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v157_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v157_dmi_read 0x38]
        echo [format "V157_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v157_read {addr label} {
    v157_sba_idle ${label}_PRE 1
    v157_dmi_write 0x38 0x20140404
    v157_sba_idle ${label}_READ_MODE 1
    v157_dmi_write 0x39 $addr
    v157_sba_idle ${label}_READ_DONE 50
    set value [v157_dmi_read 0x3C]
    v157_sba_idle ${label}_DATA_READ 1
    v157_dmi_write 0x38 0x20040404
    echo [format "V157_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v157_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v157_dmi_read 0x11]
    echo [format "V157_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v157_expect {addr expected label} {
    set got [v157_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v157_write {addr value label} {
    if {$::v157_writes >= [llength $::v157_allowed]} {error "WRITE_BUDGET"}
    set pair [lindex $::v157_allowed $::v157_writes]
    if {$addr != [lindex $pair 0] || $value != [lindex $pair 1]} {error "WRITE_ORDER_DENIED"}
    if {$addr == 0x40002828 && $value == 2 && !$::v157_stop_allowed} {error "STOP_DENIED"}
    v157_halted
    v157_expect 0x40000200 3 ${label}_PARK_ODR_RELEASED
    v157_sba_idle ${label}_PRE 1
    v157_dmi_write 0x38 0x20040404
    v157_sba_idle ${label}_WRITE_MODE 1
    v157_dmi_write 0x39 $addr
    v157_sba_idle ${label}_ADDRESS 1
    incr ::v157_writes
    echo [format "V157_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v157_writes $label $addr $value [clock milliseconds]]
    v157_dmi_write 0x3C $value
    v157_sba_idle ${label}_WRITE_DONE 50
}

proc v157_snapshot {phase i} {
    v157_halted
    set status [v157_read 0x4000283C ${phase}_STA_$i]
    set fifo [v157_read 0x4000280C ${phase}_FIFO_$i]
    set raw [v157_read 0x40002858 ${phase}_RAW_$i]
    echo [format "V157_SAMPLE %s i=%d t_ms=%s fifo=0x%08X sta=0x%08X raw=0x%08X" $phase $i [clock milliseconds] $fifo $status $raw]
    return [list $fifo $status $raw]
}

proc v157_run {} {
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
    echo "V157_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v157_halts
        echo "V157_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v157_halted
    foreach {addr value label} {
        0x4002180C 0x21 CLKEN 0x40021810 0 RST
        0x40000200 3 ODR 0x40000204 3 DIR 0x40000258 3 OSOD
        0x4000025C 0 PUPD 0x40000260 0 SPEED 0x40000264 3 DRIVE
        0x40000268 0x1B AFR1 0x4000026C 0 AFR2
        0x40000068 0 GPIOA_AFR1 0x40000168 0 GPIOB_AFR1
        0x40002810 0x3E7 DIV0 0x40002814 0x3E7 DIV1
        0x40002838 5 HOLD 0x40002820 1 MODE
        0x40002800 0xF MODULE 0x40002824 0x3C ADDR
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v157_expect $addr $value TX_PRE_$label
    }
    set mctr [v157_read 0x40002828 INITIAL_MCTR]
    if {$mctr != 0 && $mctr != 2} {error "UNEXPECTED_MCTR:$mctr"}
    set payload {0x00 0xA6 0x8D 0x14 0xA5 0xAF}
    if {$mctr == 2} {lappend ::v157_allowed {0x40002828 0}}
    foreach byte $payload {
        lappend ::v157_allowed [list 0x40002808 $byte]
    }
    lappend ::v157_allowed {0x40002828 2}
    if {$mctr == 2} {
        v157_write 0x40002828 0 HOLD_SCL_BETWEEN_BYTES
    }
    v157_expect 0x40002828 0 MCTR_HOLD_CHECK
    set index 0
    foreach byte $payload {
        v157_write 0x40002808 $byte TX_BYTE_$index
        set drained 0
        for {set i 0} {$i < 12} {incr i} {
            foreach {fifo status raw} [v157_snapshot TX_${index} $i] {break}
            if {$raw != 0} {error [format "TX_RAW_EVENT byte=%d raw=0x%08X" $index $raw]}
            set tx_count [expr {($fifo >> 8) & 0xF}]
            if {$tx_count > 1} {error "UNEXPECTED_TX_COUNT"}
            if {$tx_count == 0 && ($status & 3) == 3} {
                set drained 1
                break
            }
            sleep 2
        }
        if {!$drained} {error "TX_NOT_DRAINED_BYTE_$index"}
        echo [format "V157_BYTE_DRAINED index=%d value=0x%02X" $index $byte]
        incr index
    }
    set ::v157_stop_allowed 1
    v157_write 0x40002828 2 STOP_AFTER_DRAIN
    for {set i 0} {$i < 12} {incr i} {
        foreach {fifo status raw} [v157_snapshot STOP $i] {break}
        if {$raw & ~0x1000} {error [format "STOP_RAW_EVENT:0x%08X" $raw]}
        if {(($fifo >> 8) & 0xF) == 0 && ($status & 1) == 0} {
            return DISPLAY_FRAME_DRAINED_STOP_IDLE
        }
        sleep 2
    }
    return DISPLAY_FRAME_STOP_NOT_IDLE
}

set rc [catch {v157_run} result]
if {$rc} {
    echo "V157_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
}
echo "V157_RESULT=$result HALTS=$::v157_halts WRITES=$::v157_writes"
echo "V157_COMPLETE"
shutdown
