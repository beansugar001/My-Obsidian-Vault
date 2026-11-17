set ::v156_writes 0
set ::v156_halts 0
set ::v156_stop_allowed 0
set ::v156_allowed {
    {0x40000200 0x3} {0x40000264 0x3} {0x40000204 0x3}
    {0x40000268 0x1B} {0x4002180C 0x21}
    {0x40002810 0x3E7} {0x40002814 0x3E7} {0x40002828 0x0}
    {0x40002838 0x5} {0x40002800 0xC} {0x40002820 0x1}
    {0x40002824 0x3C} {0x40002800 0xD}
    {0x40002808 0x00} {0x40002828 0x2}
}

proc v156_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v156_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V156_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v156_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v156_dmi_read 0x38]
        echo [format "V156_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v156_read {addr label} {
    v156_sba_idle ${label}_PRE 1
    v156_dmi_write 0x38 0x20140404
    v156_sba_idle ${label}_READ_MODE 1
    v156_dmi_write 0x39 $addr
    v156_sba_idle ${label}_READ_DONE 50
    set value [v156_dmi_read 0x3C]
    v156_sba_idle ${label}_DATA_READ 1
    v156_dmi_write 0x38 0x20040404
    echo [format "V156_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v156_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v156_dmi_read 0x11]
    echo [format "V156_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v156_expect {addr expected label} {
    set got [v156_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v156_write {addr value label} {
    if {$::v156_writes >= [llength $::v156_allowed]} {error "WRITE_BUDGET"}
    set pair [lindex $::v156_allowed $::v156_writes]
    if {$addr != [lindex $pair 0] || $value != [lindex $pair 1]} {error "WRITE_ORDER_DENIED"}
    if {$::v156_writes == 14 && !$::v156_stop_allowed} {error "STOP_DENIED"}
    v156_halted
    if {$addr == 0x40000200} {
        v156_expect 0x40000204 0 ODR_WRITE_PARK_DIR
    } else {
        v156_expect 0x40000200 3 ${label}_PARK_ODR_RELEASED
    }
    v156_sba_idle ${label}_PRE 1
    v156_dmi_write 0x38 0x20040404
    v156_sba_idle ${label}_WRITE_MODE 1
    v156_dmi_write 0x39 $addr
    v156_sba_idle ${label}_ADDRESS 1
    incr ::v156_writes
    echo [format "V156_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v156_writes $label $addr $value [clock milliseconds]]
    v156_dmi_write 0x3C $value
    v156_sba_idle ${label}_WRITE_DONE 50
}

proc v156_snapshot {phase i} {
    v156_halted
    set status [v156_read 0x4000283C ${phase}_STA_$i]
    set fifo [v156_read 0x4000280C ${phase}_FIFO_$i]
    set raw [v156_read 0x40002858 ${phase}_RAW_$i]
    echo [format "V156_SAMPLE %s i=%d t_ms=%s fifo=0x%08X sta=0x%08X raw=0x%08X" $phase $i [clock milliseconds] $fifo $status $raw]
    return [list $fifo $status $raw]
}

proc v156_run {} {
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
    echo "V156_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v156_halts
        echo "V156_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v156_halted
    for {set i 0} {$i < 3} {incr i} {
        v156_expect 0x4002180C 1 GPIO_CLOCK_ONLY_$i
        v156_expect 0x40021810 0 RST_CLEAR_$i
    }
    foreach {addr label} {
        0x40000204 DIR 0x40000268 AFR1 0x4000026C AFR2
        0x40000200 ODR 0x4000025C PUPD 0x40000260 SPEED 0x40000264 DRIVE
        0x40000068 GPIOA_AFR1 0x40000168 GPIOB_AFR1
    } {
        v156_expect $addr 0 H2_BASE_$label
    }
    v156_expect 0x40000258 3 GPIOC_OPEN_DRAIN
    for {set i 0} {$i < 3} {incr i} {
        if {([v156_read 0x40000250 H2_IDLE_$i] & 3) != 3} {
            error "H2_NOT_IDLE_HIGH"
        }
    }
    foreach {addr value label} {
        0x40000200 3 GPIOC_RELEASE_LATCH
        0x40000264 3 GPIOC_HIGH_DRIVE
        0x40000204 3 GPIOC_DIRECTION
        0x40000268 0x1B GPIOC_AF3
        0x4002180C 0x21 I2C_CLOCK
    } {
        v156_write $addr $value $label
        v156_expect $addr $value ${label}_VERIFY
    }
    foreach {addr value label} {
        0x40021810 0 RST 0x40002800 2 MODULE
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v156_expect $addr $value I2C_COLD_$label
    }
    foreach {addr value readback label} {
        0x40002810 0x3E7 0x3E7 DIV0
        0x40002814 0x3E7 0x3E7 DIV1
        0x40002828 0x0 0x0 MCTR
        0x40002838 0x5 0x5 HOLD
        0x40002800 0xC 0xE FIFO_ENABLE
        0x40002820 0x1 0x1 MASTER_MODE
        0x40002824 0x3C 0x3C OLED_ADDR
        0x40002800 0xD 0xF I2C_ENABLE
    } {
        v156_write $addr $value $label
        v156_expect $addr $readback ${label}_VERIFY
    }
    foreach {addr value label} {
        0x4002180C 0x21 CLKEN 0x40021810 0 RST
        0x40000200 3 ODR 0x40000204 3 DIR 0x40000258 3 OSOD
        0x4000025C 0 PUPD 0x40000260 0 SPEED 0x40000264 3 DRIVE
        0x40000268 0x1B AFR1 0x4000026C 0 AFR2
        0x40000068 0 GPIOA_AFR1 0x40000168 0 GPIOB_AFR1
        0x40002810 0x3E7 DIV0 0x40002814 0x3E7 DIV1
        0x40002828 0 MCTR 0x40002838 5 HOLD 0x40002820 1 MODE
        0x40002800 0xF MODULE 0x40002824 0x3C ADDR
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v156_expect $addr $value TX_PRE_$label
    }
    v156_write 0x40002808 0x00 ONE_CONTROL_BYTE

    set seen_data 0
    set seen_queued 0
    for {set i 0} {$i < 60} {incr i} {
        foreach {fifo status raw} [v156_snapshot TX $i] {break}
        if {$raw & ~0x1000} {error [format "TX_RAW_EVENT:0x%08X" $raw]}
        set tx_count [expr {($fifo >> 8) & 0xF}]
        set work [expr {$status & 1}]
        if {$status & 2} {set seen_data 1}
        if {$tx_count == 1} {set seen_queued 1}
        if {$tx_count > 1 || ($raw != 0 && ($tx_count != 0 || $work))} {
            error "UNEXPECTED_TX_STATE"
        }
        if {$tx_count == 0 && !$work} {
            if {$seen_data || $seen_queued || $raw == 0x1000} {
                echo "V156_TX_DATA_SEEN=$seen_data"
                return "TX_EMPTY_AND_IDLE"
            }
        }
        if {$tx_count == 0 && $work && $seen_data && $raw == 0} {
            set ::v156_stop_allowed 1
            v156_write 0x40002828 0x2 STOP_AFTER_DRAIN
            for {set j 0} {$j < 20} {incr j} {
                foreach {fifo status raw} [v156_snapshot STOP $j] {break}
                if {$raw & ~0x1000} {error [format "STOP_RAW_EVENT:0x%08X" $raw]}
                if {(($fifo >> 8) & 0xF) == 0 && ($status & 1) == 0} {
                    return "TX_DRAINED_STOP_IDLE"
                }
                sleep 2
            }
            return "TX_DRAINED_STOP_NOT_IDLE"
        }
        sleep 2
    }
    if {$tx_count == 1 && $work && !$seen_data && $raw == 0} {
        return "TX_STALLED_FIFO_1_WORK_1"
    }
    return "TX_PROGRESS_UNKNOWN"
}

set rc [catch {v156_run} result]
if {$rc} {
    echo "V156_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
}
echo "V156_RESULT=$result HALTS=$::v156_halts WRITES=$::v156_writes"
echo "V156_COMPLETE"
shutdown
