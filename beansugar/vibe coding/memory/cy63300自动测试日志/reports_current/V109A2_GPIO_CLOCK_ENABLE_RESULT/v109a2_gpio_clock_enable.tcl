# V109A2: one halt at most; one target MMIO write; GPIO reads are gated.
set ::v109a2_status "INCOMPLETE_OR_UNKNOWN"
set ::v109a2_target_write_count 0
set ::v109a2_halt_count 0
set ::v109a2_probe_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
set ::v109a2_gpio_status "NOT_REACHED"
proc v109a2_dread {reg} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> raw]} { error "V109A2_DMI_READ_PARSE_FAIL reg=[format 0x%X $reg] out=<$out>" }
    scan $raw %x value; return [expr {$value & 0xffffffff}]
}
proc v109a2_dwrite {reg value label} {
    echo [format "V109A2_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]]
}
proc v109a2_sb_status {label} {
    set s [v109a2_dread 0x38]; echo [format "V109A2_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "V109A2_SBA_BUSY_OR_ERROR label=$label value=[format 0x%08X $s]" }
    return $s
}
proc v109a2_read {addr label} {
    v109a2_sb_status "${label}_BEFORE"
    v109a2_dwrite 0x38 0x20140404 "${label}_READ_MODE"
    v109a2_sb_status "${label}_MODE"
    v109a2_dwrite 0x39 $addr "${label}_ADDRESS"
    set v [v109a2_dread 0x3c]
    v109a2_sb_status "${label}_AFTER"
    echo [format "V109A2_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
proc v109a2_triplet {addr label expected} {
    set a [v109a2_read $addr "${label}_1"]; sleep 10
    set b [v109a2_read $addr "${label}_2"]; sleep 10
    set c [v109a2_read $addr "${label}_3"]
    echo [format "V109A2_TRIPLET label=%s values=%08X,%08X,%08X" $label $a $b $c]
    if {$a != $b || $b != $c || $a != $expected} { error "V109A2_${label}_PRECONDITION expected=[format 0x%08X $expected] got=[format %08X $a],[format %08X $b],[format %08X $c]" }
    return $a
}
proc v109a2_wait_write_idle {} {
    for {set i 0} {$i < 50} {incr i} {
        set s [v109a2_dread 0x38]
        echo [format "V109A2_WRITE_SBCS_POLL_%02d=0x%08X" $i $s]
        if {$s & 0x00407000} { error "V109A2_SBA_WRITE_ERROR value=[format 0x%08X $s]" }
        if {($s & 0x00200000) == 0} { return $s }
        sleep 1
    }
    error "V109A2_SBA_WRITE_BUSY_TIMEOUT"
}
set rc [catch {
    set il [capture {init}]; echo "V109A2_INIT_BEGIN"; echo $il; echo "V109A2_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} { error "V109A2_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} { error "V109A2_TAP_OR_IDCODE_ERROR" }
    if {![regexp -- $::v109a2_probe_serial $il]} { error "V109A2_PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]; echo "V109A2_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} { set hout [capture {halt 2000}]; incr ::v109a2_halt_count; echo "V109A2_HALT_OUTPUT=$hout"; set cpu [riscv.cpu curstate] }
    echo "V109A2_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v109a2_halt_count > 1} { error "V109A2_HALT_FAILED" }
    set dm [v109a2_dread 0x11]; echo [format "V109A2_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "V109A2_DMSTATUS_NOT_HALTED" }
    v109a2_sb_status PREFLIGHT
    v109a2_triplet 0x4002180c PERI_CLKEN_PRE 0
    v109a2_triplet 0x40021810 PERI_RST_PRE 0

    v109a2_dwrite 0x38 0x20040404 WRITE_MODE
    v109a2_sb_status WRITE_MODE_IDLE
    v109a2_dwrite 0x39 0x4002180c WRITE_ADDRESS
    v109a2_sb_status WRITE_ADDRESS_IDLE
    incr ::v109a2_target_write_count
    echo "V109A2_TARGET_MMIO_WRITE_ATTEMPT addr=0x4002180C value=0x00000001 count=1"
    v109a2_dwrite 0x3c 0x00000001 TARGET_PERI_CLKEN_WRITE
    v109a2_wait_write_idle

    v109a2_triplet 0x4002180c PERI_CLKEN_POST 1
    v109a2_triplet 0x40021810 PERI_RST_POST 0
    foreach {label addr} {GPIOB_ODR 0x40000100 GPIOB_DIR 0x40000104 GPIOB_IDR 0x40000150 GPIOB_OSOD 0x40000158 GPIOB_PUPD 0x4000015c GPIOB_AFR1 0x40000168 GPIOB_AFR2 0x4000016c} { v109a2_read $addr $label }
    set ::v109a2_gpio_status "READ_CLOCK_ON"
    set ::v109a2_status "PASS_GPIO_CLOCK_ON_SNAPSHOT"
} err]
if {$rc} { set ::v109a2_status "FAIL_OR_UNKNOWN"; echo "V109A2_ERROR=$err" }
set sbrc [catch {v109a2_sb_status FINAL} sbv]; echo [format "V109A2_FINAL_SBCS rc=%d value=%s" $sbrc $sbv]
set dmrc [catch {v109a2_dread 0x11} dmv]; echo [format "V109A2_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv]
echo [format "V109A2_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d GPIO=%s" $::v109a2_status $::v109a2_halt_count $::v109a2_target_write_count $::v109a2_gpio_status]
echo "V109A2_COMPLETE"
shutdown
