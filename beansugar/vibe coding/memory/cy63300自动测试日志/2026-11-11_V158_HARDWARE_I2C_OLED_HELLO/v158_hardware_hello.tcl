set ::v158_writes 0
set ::v158_halts 0
set ::v158_stop_allowed 0
set ::v158_allowed {}

proc v158_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v158_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V158_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v158_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v158_dmi_read 0x38]
        echo [format "V158_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v158_read {addr label} {
    v158_sba_idle ${label}_PRE 1
    v158_dmi_write 0x38 0x20140404
    v158_sba_idle ${label}_READ_MODE 1
    v158_dmi_write 0x39 $addr
    v158_sba_idle ${label}_READ_DONE 50
    set value [v158_dmi_read 0x3C]
    v158_sba_idle ${label}_DATA_READ 1
    v158_dmi_write 0x38 0x20040404
    echo [format "V158_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v158_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v158_dmi_read 0x11]
    echo [format "V158_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v158_expect {addr expected label} {
    set got [v158_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v158_write {addr value label} {
    if {$::v158_frame_writes >= [llength $::v158_allowed]} {error "WRITE_BUDGET"}
    set pair [lindex $::v158_allowed $::v158_frame_writes]
    if {$addr != [lindex $pair 0] || $value != [lindex $pair 1]} {error "WRITE_ORDER_DENIED"}
    if {$addr == 0x40002828 && $value == 2 && !$::v158_stop_allowed} {error "STOP_DENIED"}
    v158_halted
    v158_expect 0x40000200 3 ${label}_PARK_ODR_RELEASED
    v158_sba_idle ${label}_PRE 1
    v158_dmi_write 0x38 0x20040404
    v158_sba_idle ${label}_WRITE_MODE 1
    v158_dmi_write 0x39 $addr
    v158_sba_idle ${label}_ADDRESS 1
    incr ::v158_writes
    incr ::v158_frame_writes
    echo [format "V158_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v158_writes $label $addr $value [clock milliseconds]]
    v158_dmi_write 0x3C $value
    v158_sba_idle ${label}_WRITE_DONE 50
}

proc v158_snapshot {phase i} {
    v158_halted
    set status [v158_read 0x4000283C ${phase}_STA_$i]
    set fifo [v158_read 0x4000280C ${phase}_FIFO_$i]
    set raw [v158_read 0x40002858 ${phase}_RAW_$i]
    echo [format "V158_SAMPLE %s i=%d t_ms=%s fifo=0x%08X sta=0x%08X raw=0x%08X" $phase $i [clock milliseconds] $fifo $status $raw]
    return [list $fifo $status $raw]
}

proc v158_run {} {
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
    echo "V158_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v158_halts
        echo "V158_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v158_halted
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
        v158_expect $addr $value TX_PRE_$label
    }
    set frames {
        {0x00 0xAE 0xD5 0x80 0xA8 0x3F 0xD3 0x00 0x40 0xA1 0xC8 0xDA 0x12 0x81 0xCF 0xD9 0xF1 0xDB 0x30 0xA4 0xA6 0x8D 0x14 0x20 0x02}
        {0x00 0xB0 0x10 0x00}
        {0x40 0x08 0xF8 0x08 0x00 0x00 0x08 0xF8 0x08 0x00 0x00 0x80 0x80 0x80 0x80 0x00 0x00 0x00 0x08 0x08 0xF8 0x00 0x00 0x00 0x00 0x00 0x08 0x08 0xF8 0x00 0x00 0x00 0x00 0x00 0x00 0x80 0x80 0x80 0x80 0x00 0x00}
        {0x00 0xB1 0x10 0x00}
        {0x40 0x20 0x3F 0x21 0x01 0x01 0x21 0x3F 0x20 0x00 0x1F 0x22 0x22 0x22 0x22 0x13 0x00 0x00 0x20 0x20 0x3F 0x20 0x20 0x00 0x00 0x00 0x20 0x20 0x3F 0x20 0x20 0x00 0x00 0x00 0x1F 0x20 0x20 0x20 0x20 0x1F 0x00}
        {0x00 0xAF}
    }
    set frame 0
    foreach payload $frames {
        echo "V158_FRAME_BEGIN frame=$frame count=[llength $payload]"
        v158_frame $payload
        echo "V158_FRAME_COMPLETE frame=$frame"
        incr frame
    }
    return HELLO_FRAMES_DRAINED_STOP_IDLE
}

proc v158_frame {payload} {
    v158_expect 0x4000280C 5 FRAME_PRE_FIFO
    v158_expect 0x4000283C 0 FRAME_PRE_STA
    v158_expect 0x40002858 0 FRAME_PRE_RAW
    set ::v158_allowed {}
    set ::v158_frame_writes 0
    set ::v158_stop_allowed 0
    set mctr [v158_read 0x40002828 INITIAL_MCTR]
    if {$mctr != 0 && $mctr != 2} {error "UNEXPECTED_MCTR:$mctr"}
    if {$mctr == 2} {lappend ::v158_allowed {0x40002828 0}}
    foreach byte $payload {
        lappend ::v158_allowed [list 0x40002808 $byte]
    }
    lappend ::v158_allowed {0x40002828 2}
    if {$mctr == 2} {
        v158_write 0x40002828 0 HOLD_SCL_BETWEEN_BYTES
    }
    v158_expect 0x40002828 0 MCTR_HOLD_CHECK
    set index 0
    foreach byte $payload {
        v158_write 0x40002808 $byte TX_BYTE_$index
        set drained 0
        for {set i 0} {$i < 12} {incr i} {
            foreach {fifo status raw} [v158_snapshot TX_${index} $i] {break}
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
        echo [format "V158_BYTE_DRAINED index=%d value=0x%02X" $index $byte]
        incr index
    }
    set ::v158_stop_allowed 1
    v158_write 0x40002828 2 STOP_AFTER_DRAIN
    for {set i 0} {$i < 12} {incr i} {
        foreach {fifo status raw} [v158_snapshot STOP $i] {break}
        if {$raw & ~0x1000} {error [format "STOP_RAW_EVENT:0x%08X" $raw]}
        if {(($fifo >> 8) & 0xF) == 0 && ($status & 1) == 0} {
            if {$raw != 0} {error "STOP_RAW_PENDING"}
            return
        }
        sleep 2
    }
    error "DISPLAY_FRAME_STOP_NOT_IDLE"
}

set rc [catch {v158_run} result]
if {$rc} {
    echo "V158_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
}
echo "V158_RESULT=$result HALTS=$::v158_halts WRITES=$::v158_writes"
echo "V158_COMPLETE"
shutdown
