set ::stage_status "INCOMPLETE_OR_UNKNOWN"
set ::halt_requests 0

proc dmi32 {reg label} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> h]} { error "DMI_PARSE:$label raw=<$raw>" }
    scan $h %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "SAMPLE %s=0x%08X" $label $v]
    return $v
}

proc mmio32 {addr label} {
    set raw [capture [format "mdw 0x%08X 1" $addr]]
    echo [format "RAW_%s_BEGIN" $label]; echo $raw; echo [format "RAW_%s_END" $label]
    if {![regexp -nocase {0x[0-9a-f]+\s*:\s*([0-9a-f]{8})} $raw -> h]} { error "MMIO_PARSE:$label raw=<$raw>" }
    scan $h %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "SAMPLE %s_ADDR=0x%08X %s=0x%08X" $label $addr $label $v]
    return $v
}

set rc [catch {
    set init_output [capture {init}]
    echo "OPENOCD_INIT_BEGIN"; echo $init_output; echo "OPENOCD_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init_output]} { error "JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init_output]} { error "TAP_IDCODE_ERROR" }
    if {![regexp -nocase {07000001006700343500000a4e57354aa5a5a5a597969908} $init_output]} { error "PROBE_SERIAL_MISMATCH" }

    set target_name [target current]
    echo "TARGET_CURRENT=$target_name"
    set state [riscv.cpu curstate]
    echo "HART_INITIAL=$state"
    if {$state eq "running"} { echo "HALT_REQUEST=ONCE"; halt 2000; incr ::halt_requests }
    set state [riscv.cpu curstate]
    echo "HART_AFTER_HALT=$state"
    if {$state ne "halted" || $::halt_requests > 1} { error "HART_NOT_HALTED" }

    set dm [dmi32 0x11 DMSTATUS]
    set sb [dmi32 0x38 SBCS]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} { error "DMSTATUS_NOT_HALTED_OR_UNAVAILABLE" }
    if {$sb & 0x00607000} { error "SBCS_BUSY_OR_ERROR" }

    set clken [mmio32 0x4002180C PERI_CLKEN]
    set peri_rst [mmio32 0x40021810 PERI_RST]
    echo [format "CLOCK_CLASS=%s" [expr {($clken & 0x20) ? "CLOCK_ON" : "CLOCK_OFF"}]]
    if {$clken & 0x1} {
        foreach {a label} {0x40000068 GPIOA_AFR1 0x40000168 GPIOB_AFR1 0x40000268 GPIOC_AFR1 0x4000006C GPIOA_AFR2 0x4000016C GPIOB_AFR2 0x4000026C GPIOC_AFR2 0x40021808 JTAG_CFG_READONLY} { mmio32 $a $label }
        foreach {addr label} {
            0x40000100 GPIOB_ODR
            0x40000104 GPIOB_DIR
            0x40000158 GPIOB_OSOD
            0x4000015C GPIOB_PUPD
            0x40000160 GPIOB_SPEED
            0x40000164 GPIOB_DRIVE
            0x40000168 GPIOB_AF_DG
        } { mmio32 $addr $label }
    } else { echo "GPIO_SNAPSHOT_SKIPPED_GPIO_CLOCK_OFF" }

    if {!($clken & 0x20)} {
        set ::stage_status "CLOCK_OFF_NO_I2C_READ"
    } elseif {$peri_rst & 0x20} {
        set ::stage_status "I2C_RESET_ASSERTED_NO_I2C_READ"
    } else {
        set vals [dict create]
        foreach {addr label} {
            0x40002800 MODULE_CTRL
            0x4000280C FIFO_STA
            0x40002810 CLK_DIV0
            0x40002814 CLK_DIV1
            0x40002820 MODE
            0x40002824 ADDR
            0x40002828 MCTR
            0x40002838 HOLD
            0x4000283C I2C_STA
            0x40002858 RAW_INTR
        } { dict set vals $label [mmio32 $addr $label] }
        set fifo [dict get $vals FIFO_STA]
        set sta [dict get $vals I2C_STA]
        set tx_num [expr {($fifo >> 8) & 0xf}]
        set rx_num [expr {($fifo >> 16) & 0xf}]
        set tx_empty [expr {$fifo & 1}]
        set rx_empty [expr {($fifo >> 2) & 1}]
        set work [expr {$sta & 1}]
        set data [expr {($sta >> 1) & 1}]
        echo [format "DECODE FIFO_TX_NUM=%d FIFO_RX_NUM=%d TX_EMPTY=%d RX_EMPTY=%d WORK=%d DATA=%d" $tx_num $rx_num $tx_empty $rx_empty $work $data]
        if {$tx_num == 0 && $rx_num == 0 && $tx_empty && $rx_empty && !$work && !$data} {
            set ::stage_status "PASS_CLEAN_I2C_BASELINE"
        } else {
            set ::stage_status "STOP_I2C_NOT_IDLE_NO_WRITE"
        }
    }
} err]

if {$rc} {
    echo "SNAPSHOT_ERROR=$err"
    if {$::stage_status eq "INCOMPLETE_OR_UNKNOWN"} { set ::stage_status "FAIL_OR_UNKNOWN" }
}
echo [format "STAGE_RESULT=%s HALT_REQUESTS=%d TARGET_MMIO_WRITES=0 RESET=0 RESUME=0 FLASH_NVR=0 FIFO_WRITES=0 I2C_EN_WRITES=0" $::stage_status $::halt_requests]
echo "STAGE_COMPLETE"
shutdown

