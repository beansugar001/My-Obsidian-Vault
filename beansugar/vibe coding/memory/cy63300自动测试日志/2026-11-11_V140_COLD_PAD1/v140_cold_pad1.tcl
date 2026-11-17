set ::v140_writes 0
set ::v140_halts 0
set ::v140_stop_allowed 0
set ::v140_allowed {
    {0x4002180C 0x1} {0x4000015C 0x300} {0x40000158 0xC}
    {0x40000100 0xC} {0x40000164 0xC} {0x40000104 0xC}
    {0x40000168 0x6C0} {0x40000068 0x30} {0x4002180C 0x21}
    {0x40002810 0x3E7} {0x40002814 0x3E7} {0x40002828 0x0}
    {0x40002838 0x5} {0x40002800 0xC} {0x40002820 0x1}
    {0x40002824 0x3C} {0x40002800 0xD}
    {0x40002808 0x00} {0x40002828 0x2}
}

proc v140_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v140_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V140_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v140_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v140_dmi_read 0x38]
        echo [format "V140_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v140_read {addr label} {
    v140_sba_idle ${label}_PRE 1
    v140_dmi_write 0x38 0x20140404
    v140_sba_idle ${label}_READ_MODE 1
    v140_dmi_write 0x39 $addr
    v140_sba_idle ${label}_READ_DONE 50
    set value [v140_dmi_read 0x3C]
    v140_sba_idle ${label}_DATA_READ 1
    v140_dmi_write 0x38 0x20040404
    echo [format "V140_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v140_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v140_dmi_read 0x11]
    echo [format "V140_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}

proc v140_expect {addr expected label} {
    set got [v140_read $addr $label]
    if {$got != $expected} {
        error [format "MISMATCH:%s expected=0x%08X actual=0x%08X" $label $expected $got]
    }
}

proc v140_write {addr value label} {
    if {$::v140_writes >= [llength $::v140_allowed]} {error "WRITE_BUDGET"}
    set pair [lindex $::v140_allowed $::v140_writes]
    if {$addr != [lindex $pair 0] || $value != [lindex $pair 1]} {error "WRITE_ORDER_DENIED"}
    if {$::v140_writes == 18 && !$::v140_stop_allowed} {error "STOP_DENIED"}
    v140_halted
    if {$::v140_writes == 0} {
        v140_expect 0x40021810 0 CLOCK_WRITE_PARK_RST
    } elseif {$addr == 0x40000100} {
        v140_expect 0x40000104 0 ODR_WRITE_PARK_DIR
    } else {
        v140_read 0x40000100 ${label}_PARK_ODR
    }
    v140_sba_idle ${label}_PRE 1
    v140_dmi_write 0x38 0x20040404
    v140_sba_idle ${label}_WRITE_MODE 1
    v140_dmi_write 0x39 $addr
    v140_sba_idle ${label}_ADDRESS 1
    incr ::v140_writes
    echo [format "V140_WRITE_ATTEMPT count=%d %s addr=0x%08X value=0x%08X t_ms=%s" $::v140_writes $label $addr $value [clock milliseconds]]
    v140_dmi_write 0x3C $value
    v140_sba_idle ${label}_WRITE_DONE 50
}

proc v140_snapshot {phase i} {
    v140_halted
    set status [v140_read 0x4000283C ${phase}_STA_$i]
    set fifo [v140_read 0x4000280C ${phase}_FIFO_$i]
    set raw [v140_read 0x40002858 ${phase}_RAW_$i]
    echo [format "V140_SAMPLE %s i=%d t_ms=%s fifo=0x%08X sta=0x%08X raw=0x%08X" $phase $i [clock milliseconds] $fifo $status $raw]
    return [list $fifo $status $raw]
}

proc v140_run {} {
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
    echo "V140_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {
        incr ::v140_halts
        echo "V140_HALT_ATTEMPT"
        echo [capture {halt 2000}]
    }
    v140_halted
    for {set i 0} {$i < 3} {incr i} {
        v140_expect 0x4002180C 0 CLKEN_COLD_$i
        v140_expect 0x40021810 0 RST_COLD_$i
    }
    v140_write 0x4002180C 0x1 GPIO_CLOCK
    v140_expect 0x4002180C 0x1 GPIO_CLOCK_VERIFY
    foreach {addr label} {
        0x40000104 DIR 0x40000168 AFR1 0x40000100 ODR
        0x40000158 OSOD 0x4000015C PUPD 0x40000160 SPEED 0x40000164 DRIVE
    } {
        v140_expect $addr 0 GPIOB_COLD_$label
    }
    v140_expect 0x40000068 0 GPIOA_COLD_AFR1
    v140_expect 0x40000004 0 GPIOA_COLD_DIR
    for {set i 0} {$i < 3} {incr i} {
        v140_read 0x40000150 IDR_BEFORE_PULL_$i
    }
    v140_write 0x4000015C 0x300 GPIOB_PULLUP
    v140_expect 0x4000015C 0x300 GPIOB_PULLUP_VERIFY
    for {set i 0} {$i < 3} {incr i} {
        if {([v140_read 0x40000150 IDR_AFTER_PULL_$i] & 0xC) != 0xC} {
            error "GPIO_INPUT_NOT_HIGH"
        }
    }
    foreach {addr value label} {
        0x40000158 0xC GPIOB_OPEN_DRAIN
        0x40000100 0xC GPIOB_RELEASE_LATCH
        0x40000164 0xC GPIOB_HIGH_DRIVE
        0x40000104 0xC GPIOB_DIRECTION
        0x40000168 0x6C0 GPIOB_AF3
        0x40000068 0x30 PAD1_AF6_KEEP_PAD0
        0x4002180C 0x21 I2C_CLOCK
    } {
        v140_write $addr $value $label
        v140_expect $addr $value ${label}_VERIFY
    }
    foreach {addr value label} {
        0x40021810 0 RST 0x40002800 2 MODULE
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v140_expect $addr $value I2C_COLD_$label
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
        v140_write $addr $value $label
        v140_expect $addr $readback ${label}_VERIFY
    }
    foreach {addr value label} {
        0x4002180C 0x21 CLKEN 0x40021810 0 RST
        0x40000100 0xC ODR 0x40000104 0xC DIR 0x40000158 0xC OSOD
        0x4000015C 0x300 PUPD 0x40000160 0 SPEED
        0x40000164 0xC DRIVE 0x40000168 0x6C0 AFR1
        0x40000068 0x30 GPIOA_AFR1 0x40000004 0 GPIOA_DIR
        0x40002810 0x3E7 DIV0 0x40002814 0x3E7 DIV1
        0x40002828 0 MCTR 0x40002838 5 HOLD 0x40002820 1 MODE
        0x40002800 0xF MODULE 0x40002824 0x3C ADDR
        0x4000280C 5 FIFO 0x4000283C 0 STA 0x40002858 0 RAW
    } {
        v140_expect $addr $value TX_PRE_$label
    }
    v140_write 0x40002808 0x00 ONE_CONTROL_BYTE

    set seen_data 0
    set seen_queued 0
    for {set i 0} {$i < 60} {incr i} {
        foreach {fifo status raw} [v140_snapshot TX $i] {break}
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
                echo "V140_TX_DATA_SEEN=$seen_data"
                return "TX_EMPTY_AND_IDLE"
            }
        }
        if {$tx_count == 0 && $work && $seen_data && $raw == 0} {
            set ::v140_stop_allowed 1
            v140_write 0x40002828 0x2 STOP_AFTER_DRAIN
            for {set j 0} {$j < 20} {incr j} {
                foreach {fifo status raw} [v140_snapshot STOP $j] {break}
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

set rc [catch {v140_run} result]
if {$rc} {
    echo "V140_ERROR=$result"
    set result "FAIL_OR_UNKNOWN"
}
echo "V140_RESULT=$result HALTS=$::v140_halts WRITES=$::v140_writes"
echo "V140_COMPLETE"
shutdown
