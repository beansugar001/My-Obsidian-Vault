# V113A3: distinguish MODULE_CTRL write value 0x0D from 0x0F.
# Current chip state is retained from V113A1: clock on, pads/master configured,
# ADDR=0x3C, MODULE_CTRL=0x0E, TX FIFO empty, controller idle.
set ::v113a3_status "INCOMPLETE_OR_UNKNOWN"
set ::v113a3_outcome "NOT_STARTED"
set ::v113a3_write_count 0
set ::v113a3_halt_count 0
set ::v113a3_stop_count 0

proc v113a3_dr {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL reg=$r <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v113a3_dw {r v label} {
    echo [format "V113A3_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v113a3_sb {label} {
    set s [v113a3_dr 0x38]
    echo [format "V113A3_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR label=$label sbcs=[format 0x%08X $s]"}
    return $s
}
proc v113a3_rd {a label} {
    v113a3_sb "${label}_PRE"
    v113a3_dw 0x38 0x20140404 "${label}_READ_MODE"
    v113a3_sb "${label}_MODE"
    v113a3_dw 0x39 $a "${label}_ADDRESS"
    set v [v113a3_dr 0x3c]
    v113a3_sb "${label}_DONE"
    echo [format "V113A3_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]
    return $v
}
proc v113a3_wr {a v label {verify 1}} {
    v113a3_sb "${label}_PRE"
    v113a3_dw 0x38 0x20040404 "${label}_WRITE_MODE"
    v113a3_sb "${label}_MODE_IDLE"
    v113a3_dw 0x39 $a "${label}_ADDRESS"
    v113a3_sb "${label}_ADDRESS_IDLE"
    incr ::v113a3_write_count
    echo [format "V113A3_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v113a3_write_count $label]
    v113a3_dw 0x3c $v "${label}_DATA"
    set done 0
    for {set i 0} {$i < 50} {incr i} {
        set s [v113a3_dr 0x38]
        echo [format "V113A3_SBA_WRITE_WAIT label=%s i=%d sbcs=0x%08X" $label $i $s]
        if {$s & 0x00407000} {error "SBA_WRITE_ERROR label=$label sbcs=[format 0x%08X $s]"}
        if {($s & 0x00200000) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {error "SBA_WRITE_TIMEOUT label=$label"}
    if {$verify} {
        set got [v113a3_rd $a "${label}_VERIFY"]
        if {$got != $v} {error "READBACK_MISMATCH label=$label expected=[format 0x%08X $v] got=[format 0x%08X $got]"}
        return $got
    }
    return 0
}
proc v113a3_stop {reason} {
    set ::v113a3_outcome $reason
    set m [v113a3_rd 0x40002828 "MCTR_PRE_STOP"]
    if {$m != 0} {error "MCTR_CHANGED_BEFORE_STOP value=[format 0x%08X $m]"}
    v113a3_wr 0x40002828 0x00000002 "STOP_AFTER_${reason}"
    incr ::v113a3_stop_count
    for {set i 0} {$i < 80} {incr i} {
        set st [v113a3_rd 0x4000283C "STOP_STATUS_$i"]
        set fs [v113a3_rd 0x4000280C "STOP_FIFO_$i"]
        set raw [v113a3_rd 0x40002858 "STOP_RAW_$i"]
        echo [format "V113A3_STOP_POLL i=%d status=0x%08X fifo=0x%08X raw=0x%08X" $i $st $fs $raw]
        if {($st & 1) == 0 && ($raw & 0x1000) != 0 && ((($fs >> 8) & 0xF) == 0)} {return 1}
        sleep 1
    }
    set ::v113a3_outcome "STOP_OR_IDLE_UNKNOWN"
    error "STOP_OR_IDLE_NOT_CONFIRMED"
}

set rc [catch {
    set il [capture {init}]
    echo "V113A3_INIT_BEGIN"; echo $il; echo "V113A3_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} {error "TAP_OR_IDCODE_MISMATCH"}
    if {![regexp {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} {error "DAPLINK_SERIAL_MISMATCH"}
    set cpu [riscv.cpu curstate]
    echo "V113A3_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {set h [capture {halt 2000}]; incr ::v113a3_halt_count; echo "V113A3_HALT=$h"; set cpu [riscv.cpu curstate]}
    echo "V113A3_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v113a3_halt_count > 1} {error "CPU_NOT_HALTED"}
    set dm [v113a3_dr 0x11]
    echo [format "V113A3_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} {error "DMSTATUS_NOT_HALTED"}
    v113a3_sb PREFLIGHT

    # Every condition is checked before the first write. Internal I2C reads are
    # valid only because V113A1 has already enabled PERI_CLKEN[5].
    foreach {label addr expected} {
        PERI_CLKEN 0x4002180C 0x21 PERI_RST 0x40021810 0
        GPIOB_IDR 0x40000150 0x2C GPIOB_AFR1 0x40000168 0x6C0
        MODULE_CTRL 0x40002800 0xF FIFO_STA 0x4000280C 5
        CLK_DIV0 0x40002810 0x0F CLK_DIV1 0x40002814 0x23
        MODE 0x40002820 1 ADDR 0x40002824 0x3C
        MCTR 0x40002828 0 HOLD 0x40002838 5
        STATUS 0x4000283C 0 RAW_INTR 0x40002858 0
    } {
        set got [v113a3_rd $addr $label]
        if {$got != $expected} {error "PRECONDITION_MISMATCH $label expected=[format 0x%08X $expected] got=[format 0x%08X $got]"}
    }

    # One OLED control byte; address is in ADDR, not repeated as raw FIFO data.
    v113a3_wr 0x40002808 0x00000000 OLED_CONTROL_BYTE_00 0
    set data_seen 0; set drained 0; set nack 0; set errflag 0
    for {set i 0} {$i < 120} {incr i} {
        set st [v113a3_rd 0x4000283C "TX_STATUS_$i"]
        set fs [v113a3_rd 0x4000280C "TX_FIFO_$i"]
        set raw [v113a3_rd 0x40002858 "TX_RAW_$i"]
        set idr [v113a3_rd 0x40000150 "TX_GPIO_IDR_$i"]
        if {$st & 2} {set data_seen 1}
        if {$raw & 0x2000} {set nack 1}
        if {$raw & 0x1C000} {set errflag $raw}
        echo [format "V113A3_TX_POLL i=%d status=0x%08X fifo=0x%08X raw=0x%08X idr=0x%08X" $i $st $fs $raw $idr]
        if {$nack || $errflag != 0} {v113a3_stop "I2C_ERROR"; break}
        if {$data_seen && ((($fs >> 8) & 0xF) == 0)} {set drained 1; v113a3_stop "DATA_DRAINED"; break}
        sleep 1
    }
    if {!$drained && !$nack && $errflag == 0} {v113a3_stop "TX_TIMEOUT"}
    set final_status [v113a3_rd 0x4000283C FINAL_STATUS]
    set final_fifo [v113a3_rd 0x4000280C FINAL_FIFO]
    set final_raw [v113a3_rd 0x40002858 FINAL_RAW]
    set final_idr [v113a3_rd 0x40000150 FINAL_GPIO_IDR]
    echo [format "V113A3_FINAL status=0x%08X fifo=0x%08X raw=0x%08X idr=0x%08X" $final_status $final_fifo $final_raw $final_idr]
    if {$drained && ($final_status & 1) == 0 && ($final_raw & 0x1000) != 0} {
        set ::v113a3_status "PASS_DATA_DRAINED_STOP_IDLE"
    } elseif {$nack} {
        set ::v113a3_status "FAIL_NACK"
    } elseif {$errflag != 0} {
        set ::v113a3_status "FAIL_I2C_ERROR"
    } elseif {$final_status == 0 && ((($final_fifo >> 8) & 0xF) == 0)} {
        set ::v113a3_status "STOPPED_WITHOUT_DATA_CONFIRMATION"
    } else {
        set ::v113a3_status "FAIL_OR_UNKNOWN_TX_STALLED"
    }
} err]
if {$rc} {set ::v113a3_status "FAIL_OR_UNKNOWN"; echo "V113A3_ERROR=$err"}
set sf [catch {v113a3_sb FINAL} sv]
set df [catch {v113a3_dr 0x11} dv]
echo [format "V113A3_FINAL_GATES sbcs_rc=%d sbcs=%s dmstatus_rc=%d dmstatus=%s" $sf $sv $df $dv]
echo [format "V113A3_RESULT=%s OUTCOME=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d STOP_WRITE_COUNT=%d" $::v113a3_status $::v113a3_outcome $::v113a3_halt_count $::v113a3_write_count $::v113a3_stop_count]
echo "V113A3_COMPLETE"
shutdown
