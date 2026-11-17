set ::v139_writes 0
set ::v139_halts 0
set ::v139_stop_allowed 0
set ::v139_allowed {
    {0x4002180C 0x1} {0x4000015C 0x300} {0x40000158 0xC}
    {0x40000100 0xC} {0x40000164 0xC} {0x40000104 0xC}
    {0x40000168 0x6C0} {0x4002180C 0x21}
    {0x40002810 0x3E7} {0x40002814 0x3E7} {0x40002828 0x0}
    {0x40002838 0x5} {0x40002800 0xC} {0x40002820 0x1}
    {0x40002824 0x3C} {0x40002800 0xD}
    {0x40002808 0x00} {0x40002828 0x2}
}

proc v139_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v139_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V139_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v139_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v139_dmi_read 0x38]
        echo [format "V139_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v139_read {addr label} {
    v139_sba_idle ${label}_PRE 1
    v139_dmi_write 0x38 0x20140404
    v139_sba_idle ${label}_READ_MODE 1
    v139_dmi_write 0x39 $addr
    v139_sba_idle ${label}_READ_DONE 50
    set value [v139_dmi_read 0x3C]
    v139_sba_idle ${label}_DATA_READ 1
    v139_dmi_write 0x38 0x20040404
    echo [format "V139_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v139_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v139_dmi_read 0x11]
    echo [format "V139_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v139_expect {addr expected label} {
    set got [v139_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v139_write {addr value label} {
    if {$::v139_writes >= [llength $::v139_allowed]} {error "WRITE_BUDGET"}
    set pair [lindex $::v139_allowed $::v139_writes]
    if {$addr != [lindex $pair 0] || $value != [lindex $pair 1]} {error "WRITE_ORDER_DENIED"}
    if {$::v139_writes == 17 && !$::v139_stop_allowed} {error "STOP_DENIED"}
    v139_halted
    if {$::v139_writes == 0} {
        v139_expect 0x40021810 0 CLOCK_WRITE_PARK_RST
    } elseif {$addr == 0x40000100} {
        v139_expect 0x40000104 0 ODR_WRITE_PARK_DIR
    } else {
        v139_read 0x40000100 ${label}_PARK_ODR
    }
    v139_sba_idle ${label}_PRE 1
    v139_dmi_write 0x38 0x20040404
    v139_sba_idle ${label}_WRITE_MODE 1
    v139_dmi_write 0x39 $addr
    v139_sba_idle ${label}_ADDRESS 1
    incr ::v139_writes
    echo [format "V139_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v139_writes $label $addr $value [clock milliseconds]]
    v139_dmi_write 0x3C $value
    v139_sba_idle ${label}_WRITE_DONE 50
}

proc v139_snapshot {phase i} {
    v139_halted
    set status [v139_read 0x4000283C ${phase}_STA_$i]
    set fifo [v139_read 0x4000280C ${phase}_FIFO_$i]
    set raw [v139_read 0x40002858 ${phase}_RAW_$i]
    echo [format "V139_SAMPLE %s i=%d t_ms=%s fifo=0x%08X sta=0x%08X raw=0x%08X" $phase $i [clock milliseconds] $fifo $status $raw]
    return [list $fifo $status $raw]
}

proc v139_run {} {
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
    echo "V139_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v139_halts
        echo "V139_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v139_halted
    for {set i 0} {$i < 3} {incr i} {
        v139_expect 0x4002180C 0 CLKEN_COLD_$i
        v139_expect 0x40021810 0 RST_COLD_$i
    }
    v139_write 0x4002180C 0x1 GPIO_CLOCK
    v139_expect 0x4002180C 0x1 GPIO_CLOCK_VERIFY
    foreach {addr label} {
        0x40000104 DIR 0x40000168 AFR1 0x40000100 ODR
        0x40000158 OSOD 0x4000015C PUPD 0x40000160 SPEED 0x40000164 DRIVE
    } {
        v139_expect $addr 0 GPIOB_COLD_$label
    }
    if {[v139_read 0x40000068 GPIOA_AFR1] & 0x3F} {error "PAD0_OR_PAD1_NOT_DEFAULT"}
    for {set i 0} {$i < 3} {incr i} {
        v139_read 0x40000150 IDR_BEFORE_PULL_$i
    }
    v139_write 0x4000015C 0x300 GPIOB_PULLUP
    v139_expect 0x4000015C 0x300 GPIOB_PULLUP_VERIFY
    for {set i 0} {$i < 3} {incr i} {
        if {([v139_read 0x40000150 IDR_AFTER_PULL_$i] & 0xC) != 0xC} {
            error "GPIO_INPUT_NOT_HIGH"
        }
    }
    foreach {addr value label} {
        0x40000158 0xC GPIOB_OPEN_DRAIN
        0x40000100 0xC GPIOB_RELEASE_LATCH
        0x40000164 0xC GPIOB_HIGH_DRIVE
        0x40000104 0xC GPIOB_DIRECTION
        0x40000168 0x6C0 GPIOB_AF3
        0x4002180C 0x21 I2C_CLOCK
    } {
        v139_write $addr $value $label
        v139_expect $addr $value ${label}_VERIFY
    }
    foreach {addr value label} {
        0x40021810 0 RST 0x40002800 2 MODULE
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v139_expect $addr $value I2C_COLD_$label
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
        v139_write $addr $value $label
        v139_expect $addr $readback ${label}_VERIFY
    }
    foreach {addr value label} {
        0x4002180C 0x21 CLKEN 0x40021810 0 RST
        0x40000100 0xC ODR 0x40000104 0xC DIR 0x40000158 0xC OSOD
        0x4000015C 0x300 PUPD 0x40000160 0 SPEED
        0x40000164 0xC DRIVE 0x40000168 0x6C0 AFR1
        0x40002810 0x3E7 DIV0 0x40002814 0x3E7 DIV1
        0x40002828 0 MCTR 0x40002838 5 HOLD 0x40002820 1 MODE
        0x40002800 0xF MODULE 0x40002824 0x3C ADDR
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v139_expect $addr $value TX_PRE_$label
    }
    v139_write 0x40002808 0x00 ONE_CONTROL_BYTE

    set seen_data 0
    set seen_queued 0
    for {set i 0} {$i < 60} {incr i} {
        foreach {fifo status raw} [v139_snapshot TX $i] {break}
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
                echo "V139_TX_DATA_SEEN=$seen_data"
                return "TX_EMPTY_AND_IDLE"
            }
        }
        if {$tx_count == 0 && $work && $seen_data && $raw == 0} {
            set ::v139_stop_allowed 1
            v139_write 0x40002828 0x2 STOP_AFTER_DRAIN
            for {set j 0} {$j < 20} {incr j} {
                foreach {fifo status raw} [v139_snapshot STOP $j] {break}
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

set rc [catch {v139_run} result]
if {$rc} {
    echo "V139_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
}
echo "V139_RESULT=$result HALTS=$::v139_halts WRITES=$::v139_writes"
echo "V139_COMPLETE"
shutdown
