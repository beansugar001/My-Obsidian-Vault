# V113A0: address-before-enable + one-byte ARM send procedure.
# This stage changes one ordering variable relative to V111A4: ADDR is set
# while FIFO is enabled but I2C_EN is still 0. It then writes exactly one
# OLED control byte (0x00), polls like IIC_Master.c, and requests one STOP.
set ::v113_status "INCOMPLETE_OR_UNKNOWN"
set ::v113_write_count 0
set ::v113_halt_count 0
set ::v113_stop_count 0
set ::v113_outcome "NOT_STARTED"

proc v113_dr {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL reg=$r <$o>"}
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v113_dw {r v label} {
    echo [format "V113_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v & 0xffffffff}]]
}
proc v113_sb {label} {
    set s [v113_dr 0x38]
    echo [format "V113_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR label=$label sbcs=[format 0x%08X $s]"}
    return $s
}
proc v113_rd {a label} {
    v113_sb "${label}_PRE"
    v113_dw 0x38 0x20140404 "${label}_READ_MODE"
    v113_sb "${label}_MODE"
    v113_dw 0x39 $a "${label}_ADDRESS"
    set v [v113_dr 0x3c]
    v113_sb "${label}_DONE"
    echo [format "V113_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]
    return $v
}
proc v113_wr {a v label} {
    v113_sb "${label}_PRE"
    v113_dw 0x38 0x20040404 "${label}_WRITE_MODE"
    v113_sb "${label}_MODE_IDLE"
    v113_dw 0x39 $a "${label}_ADDRESS"
    v113_sb "${label}_ADDRESS_IDLE"
    incr ::v113_write_count
    echo [format "V113_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v113_write_count $label]
    v113_dw 0x3c $v "${label}_DATA"
    set done 0
    for {set i 0} {$i < 50} {incr i} {
        set s [v113_dr 0x38]
        echo [format "V113_SBA_WRITE_WAIT label=%s i=%d sbcs=0x%08X" $label $i $s]
        if {$s & 0x00407000} {error "SBA_WRITE_ERROR label=$label sbcs=[format 0x%08X $s]"}
        if {($s & 0x00200000) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {error "SBA_WRITE_TIMEOUT label=$label"}
    set got [v113_rd $a "${label}_VERIFY"]
    if {$got != $v} {error "READBACK_MISMATCH label=$label expected=[format 0x%08X $v] got=[format 0x%08X $got]"}
    return $got
}
proc v113_stop_and_observe {reason} {
    set ::v113_outcome $reason
    set m [v113_rd 0x40002828 "MCTR_PRE_STOP_${reason}"]
    if {$m != 0} {error "MCTR_CHANGED_BEFORE_STOP value=[format 0x%08X $m]"}
    v113_wr 0x40002828 0x00000002 "STOP_AFTER_${reason}"
    incr ::v113_stop_count
    set done 0
    for {set i 0} {$i < 80} {incr i} {
        set st [v113_rd 0x4000283C "STOP_STATUS_$i"]
        set fs [v113_rd 0x4000280C "STOP_FIFO_$i"]
        set raw [v113_rd 0x40002858 "STOP_RAW_$i"]
        echo [format "V113_STOP_POLL i=%d status=0x%08X fifo=0x%08X raw=0x%08X" $i $st $fs $raw]
        if {($st & 1) == 0 && ($raw & 0x1000) != 0 && (($fs >> 8) & 0xF) == 0} {set done 1; break}
        sleep 1
    }
    if {!$done} {set ::v113_outcome "STOP_OR_IDLE_UNKNOWN"; error "STOP_OR_IDLE_NOT_CONFIRMED"}
    return 1
}

set rc [catch {
    set il [capture {init}]
    echo "V113_INIT_BEGIN"; echo $il; echo "V113_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} {error "OPENOCD_INIT_ERROR"}
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} {error "TAP_OR_IDCODE_MISMATCH"}
    if {![regexp {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} {error "DAPLINK_SERIAL_MISMATCH"}

    set cpu [riscv.cpu curstate]
    echo "V113_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} {set h [capture {halt 2000}]; incr ::v113_halt_count; echo "V113_HALT=$h"; set cpu [riscv.cpu curstate]}
    echo "V113_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v113_halt_count > 1} {error "CPU_NOT_HALTED"}
    set dm [v113_dr 0x11]
    echo [format "V113_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} {error "DMSTATUS_NOT_HALTED"}
    v113_sb PREFLIGHT

    # Fresh-state gate: no active controller/FIFO work and no reset asserted.
    set clk [v113_rd 0x4002180C PERI_CLKEN_PRE]
    set rst [v113_rd 0x40021810 PERI_RST_PRE]
    set mc [v113_rd 0x40002800 MODULE_CTRL_PRE]
    set fs [v113_rd 0x4000280C FIFO_STA_PRE]
    set st [v113_rd 0x4000283C I2C_STATUS_PRE]
    set raw [v113_rd 0x40002858 RAW_INTR_PRE]
    set idr [v113_rd 0x40000150 GPIOB_IDR_PRE]
    echo [format "V113_BASELINE clken=0x%08X rst=0x%08X module=0x%08X fifo=0x%08X status=0x%08X raw=0x%08X idr=0x%08X" $clk $rst $mc $fs $st $raw $idr]
    if {$clk != 0 && $clk != 1} {error "UNEXPECTED_PERI_CLKEN"}
    if {$rst != 0 || $mc != 2 || $fs != 5 || $st != 0 || $raw != 0} {error "I2C_NOT_CLEAN_IDLE"}

    # Enable GPIO + I2C clocks while preserving the clean reset state.
    if {$clk != 0x21} {v113_wr 0x4002180C 0x00000021 PERI_CLKEN_GPIO_I2C}
    if {[v113_rd 0x4002180C PERI_CLKEN_POST] != 0x21} {error "CLOCK_READBACK_FAILED"}

    # Pad8/9 = PB2/PB3 AF3; open-drain, released-high; weak internal pulls on.
    v113_wr 0x40000100 0x0000000C GPIOB_ODR_RELEASE
    v113_wr 0x40000158 0x0000000C GPIOB_OSOD_OPEN_DRAIN
    v113_wr 0x40000104 0x0000000C GPIOB_DIR_OUTPUT
    v113_wr 0x4000015C 0x00000300 GPIOB_PUPD_PULLUP
    set idr [v113_rd 0x40000150 GPIOB_IDR_RELEASED]
    echo [format "V113_GPIO_RELEASE_IDR=0x%08X" $idr]
    if {($idr & 0xC) != 0xC} {error "SCL_OR_SDA_NOT_HIGH_BEFORE_AF"}
    v113_wr 0x40000168 0x000006C0 GPIOB_AFR1_PAD8_PAD9_AF3
    set afr [v113_rd 0x40000168 GPIOB_AFR1_VERIFY]
    if {$afr != 0x6C0} {error "PADMUX_READBACK_FAILED"}

    # ARM I2C_MasterInit ordering; FIFO enabled, controller still disabled.
    v113_wr 0x40002810 0x0000000F CLK_DIV0_H_0x10_MINUS_1
    v113_wr 0x40002814 0x00000023 CLK_DIV1_L_0x24_MINUS_1
    v113_wr 0x40002828 0x00000000 MCTR_7BIT_STOP_HOLD_SCL_LOW
    v113_wr 0x40002838 0x00000005 HOLD
    v113_wr 0x40002800 0x0000000E FIFO_ENABLES_I2C_DISABLED
    v113_wr 0x40002820 0x00000001 MASTER_MODE
    # Key ordering trial: target address is configured before I2C_EN.
    v113_wr 0x40002824 0x0000003C TARGET_ADDRESS_7BIT_BEFORE_ENABLE
    set got [v113_rd 0x40002824 ADDR_BEFORE_ENABLE_VERIFY]
    if {$got != 0x3C} {error "ADDR_PRE_ENABLE_READBACK_FAILED"}
    set module [v113_rd 0x40002800 MODULE_CTRL_FIFO_ONLY]
    if {$module != 0xE} {error "FIFO_ONLY_STATE_MISMATCH"}
    v113_wr 0x40002800 0x0000000F I2C_ENABLE_AFTER_ADDRESS
    set module [v113_rd 0x40002800 MODULE_CTRL_ENABLED]
    if {$module != 0xF} {error "I2C_ENABLE_READBACK_FAILED"}

    # One data/control byte only. ADDR is a separate target-address register;
    # do not push 0x78 as a raw FIFO byte in this trial.
    v113_wr 0x40002808 0x00000000 OLED_CONTROL_BYTE_00
    set data_seen 0; set drained 0; set nack 0; set errflag 0
    for {set i 0} {$i < 120} {incr i} {
        set status [v113_rd 0x4000283C "TX_STATUS_$i"]
        set fifo [v113_rd 0x4000280C "TX_FIFO_$i"]
        set raw [v113_rd 0x40002858 "TX_RAW_$i"]
        set idr [v113_rd 0x40000150 "TX_IDR_$i"]
        if {$status & 1} {set ::v113_seen_work 1}
        if {$status & 2} {set data_seen 1}
        if {$raw & 0x2000} {set nack 1}
        if {$raw & 0x1C000} {set errflag $raw}
        echo [format "V113_TX_POLL i=%d status=0x%08X fifo=0x%08X raw=0x%08X idr=0x%08X" $i $status $fifo $raw $idr]
        if {$nack || $errflag != 0} {set ::v113_outcome "I2C_ERROR raw=[format 0x%08X $raw]"; v113_stop_and_observe I2C_ERROR; break}
        if {$data_seen && ((($fifo >> 8) & 0xF) == 0)} {set drained 1; set ::v113_outcome "DATA_SEEN_FIFO_EMPTY"; v113_stop_and_observe DATA_SEEN_FIFO_EMPTY; break}
        sleep 1
    }
    if {!$drained && !$nack && $errflag == 0} {
        # Follow the ARM sample's bounded-timeout STOP path once, then stop.
        set ::v113_outcome "TX_TIMEOUT_STOP_ATTEMPTED"
        v113_stop_and_observe TX_TIMEOUT
    }
    set final_status [v113_rd 0x4000283C FINAL_STATUS]
    set final_fifo [v113_rd 0x4000280C FINAL_FIFO]
    set final_raw [v113_rd 0x40002858 FINAL_RAW]
    set final_idr [v113_rd 0x40000150 FINAL_GPIO_IDR]
    echo [format "V113_FINAL status=0x%08X fifo=0x%08X raw=0x%08X idr=0x%08X outcome=%s" $final_status $final_fifo $final_raw $final_idr $::v113_outcome]
    if {$drained && ($final_status & 1) == 0 && ($final_raw & 0x1000) != 0} {
        set ::v113_status "PASS_DATA_DRAINED_STOP_IDLE"
    } elseif {$nack} {
        set ::v113_status "FAIL_NACK"
    } elseif {$errflag != 0} {
        set ::v113_status "FAIL_I2C_ERROR"
    } elseif {$final_status == 0 && ((($final_fifo >> 8) & 0xF) == 0)} {
        set ::v113_status "STOPPED_WITHOUT_DATA_CONFIRMATION"
    } else {
        set ::v113_status "FAIL_OR_UNKNOWN_TX_STALLED"
    }
} err]
if {$rc} {set ::v113_status "FAIL_OR_UNKNOWN"; echo "V113_ERROR=$err"}
set sf [catch {v113_sb FINAL} sv]
set df [catch {v113_dr 0x11} dv]
echo [format "V113_FINAL_GATES sbcs_rc=%d sbcs=%s dmstatus_rc=%d dmstatus=%s" $sf $sv $df $dv]
echo [format "V113_RESULT=%s OUTCOME=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d STOP_WRITE_COUNT=%d" $::v113_status $::v113_outcome $::v113_halt_count $::v113_write_count $::v113_stop_count]
echo "V113_COMPLETE"
shutdown
