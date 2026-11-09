# V109B: single gated I2C-clock write; post-write read-only controller baseline.
set ::v109b_status "INCOMPLETE_OR_UNKNOWN"
set ::v109b_write_count 0
set ::v109b_halt_count 0
proc v109b_dread {reg} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> raw]} { error "DMI_READ_PARSE_FAIL reg=[format 0x%X $reg] out=<$out>" }
    scan $raw %x value; return [expr {$value & 0xffffffff}]
}
proc v109b_dwrite {reg value label} {
    echo [format "V109B_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]]
}
proc v109b_sb_ok {label} {
    set s [v109b_dread 0x38]
    echo [format "V109B_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "SBA_BUSY_OR_ERROR label=$label value=[format 0x%08X $s]" }
    return $s
}
proc v109b_mmio_read {addr label} {
    v109b_sb_ok "${label}_BEFORE"
    v109b_dwrite 0x38 0x20140404 "${label}_READ_MODE"
    v109b_sb_ok "${label}_MODE"
    v109b_dwrite 0x39 $addr "${label}_ADDRESS"
    set v [v109b_dread 0x3c]
    v109b_sb_ok "${label}_AFTER"
    echo [format "V109B_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc v109b_triplet {addr label expected} {
    set a [v109b_mmio_read $addr "${label}_1"]; sleep 10
    set b [v109b_mmio_read $addr "${label}_2"]; sleep 10
    set c [v109b_mmio_read $addr "${label}_3"]
    echo [format "V109B_TRIPLET label=%s values=%08X,%08X,%08X" $label $a $b $c]
    if {$a != $b || $b != $c || $a != $expected} { error "TRIPLET_MISMATCH label=$label expected=[format 0x%08X $expected] got=[format %08X $a],[format %08X $b],[format %08X $c]" }
    return $a
}
set rc [catch {
    set il [capture {init}]; echo "V109B_INIT_BEGIN"; echo $il; echo "V109B_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} { error "OPENOCD_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} { error "TAP_OR_IDCODE_MISMATCH" }
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} { error "PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]; echo "V109B_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} { set hout [capture {halt 2000}]; incr ::v109b_halt_count; echo "V109B_HALT_OUTPUT=$hout"; set cpu [riscv.cpu curstate] }
    echo "V109B_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v109b_halt_count > 1} { error "HALT_FAILED" }
    set dm [v109b_dread 0x11]; echo [format "V109B_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "DMSTATUS_NOT_HALTED" }
    v109b_sb_ok PREFLIGHT
    v109b_triplet 0x4002180c PERI_CLKEN_PRE 1
    v109b_triplet 0x40021810 PERI_RST_PRE 0

    v109b_dwrite 0x38 0x20040404 WRITE_MODE
    v109b_sb_ok WRITE_MODE_IDLE
    v109b_dwrite 0x39 0x4002180c WRITE_ADDRESS
    v109b_sb_ok WRITE_ADDRESS_IDLE
    incr ::v109b_write_count
    echo "V109B_TARGET_MMIO_WRITE_ATTEMPT addr=0x4002180C value=0x00000021 count=1"
    v109b_dwrite 0x3c 0x00000021 TARGET_PERI_CLKEN_I2C_GATE
    for {set i 0} {$i < 50} {incr i} {
        set s [v109b_dread 0x38]
        echo [format "V109B_WRITE_SBCS_POLL_%02d=0x%08X" $i $s]
        if {$s & 0x00407000} { error "SBA_WRITE_ERROR" }
        if {($s & 0x00200000) == 0} { break }
        sleep 1
    }
    if {$i == 50} { error "SBA_WRITE_BUSY_TIMEOUT" }
    v109b_triplet 0x4002180c PERI_CLKEN_POST 0x21
    v109b_triplet 0x40021810 PERI_RST_POST 0

    # Read only non-FIFO-data registers; reading FIFO would consume RX data.
    foreach {label addr} {MODULE_CTRL 0x40002800 FIFO_STA 0x4000280C CLK_DIV0 0x40002810 CLK_DIV1 0x40002814 MODE 0x40002820 ADDR 0x40002824 MCTR 0x40002828 HOLD 0x40002838 STATUS 0x4000283C RAW_INTR_STA 0x40002858} {
        set v [v109b_mmio_read $addr $label]
        set ::v109b_reg_$label $v
    }
    set module $::v109b_reg_MODULE_CTRL
    echo [format "V109B_CONTROLLER_ENABLE_BITS i2c_en=%d tx_fifo_en=%d rx_fifo_en=%d" [expr {$module & 1}] [expr {($module >> 2) & 1}] [expr {($module >> 3) & 1}]]
    if {$module & 0xD} { error "CONTROLLER_OR_FIFO_ENABLE_NOT_ZERO; STOP_BEFORE_PINMUX_OR_TRANSACTION" }
    set ::v109b_status "PASS_I2C_CLOCK_ON_CONTROLLER_BASELINE"
} err]
if {$rc} { set ::v109b_status "FAIL_OR_UNKNOWN"; echo "V109B_ERROR=$err" }
set sbrc [catch {v109b_sb_ok FINAL} sbv]; echo [format "V109B_FINAL_SBCS rc=%d value=%s" $sbrc $sbv]
set dmrc [catch {v109b_dread 0x11} dmv]; echo [format "V109B_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv]
echo [format "V109B_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v109b_status $::v109b_halt_count $::v109b_write_count]
echo "V109B_COMPLETE"
shutdown