# V109A: exactly one target write (PERI_CLKEN=1), then read-only checks.
set ::v109a_status "INCOMPLETE_OR_UNKNOWN"
set ::v109a_target_write_count 0
set ::v109a_probe_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
set ::v109a_gpio_status "NOT_REACHED"

proc v109a_dread {reg} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> raw]} { error "V109A_DMI_READ_PARSE_FAIL reg=[format 0x%X $reg] out=<$out>" }
    scan $raw %x value
    return [expr {$value & 0xffffffff}]
}
proc v109a_dmi_write {reg value label} {
    echo [format "V109A_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]]
}
proc v109a_sb_status {label} {
    set s [v109a_dread 0x38]
    echo [format "V109A_SBCS label=%s value=0x%08X" $label $s]
    if {$s & 0x00607000} { error "V109A_SBA_BUSY_OR_ERROR label=$label value=[format 0x%08X $s]" }
    return $s
}
proc v109a_read {addr label} {
    v109a_sb_status "${label}_BEFORE"
    v109a_dmi_write 0x38 0x20140404 "${label}_READ_MODE"
    v109a_sb_status "${label}_MODE"
    v109a_dmi_write 0x39 $addr "${label}_ADDRESS"
    set value [v109a_dread 0x3c]
    v109a_sb_status "${label}_AFTER"
    echo [format "V109A_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}
proc v109a_triplet {addr label expected} {
    set values {}
    for {set i 1} {$i <= 3} {incr i} { lappend values [v109a_read $addr "${label}_${i}"]; sleep 10 }
    if {[lindex $values 0] != [lindex $values 1] || [lindex $values 1] != [lindex $values 2]} { error "V109A_UNSTABLE_${label}" }
    echo [format "V109A_TRIPLET label=%s values=%08X,%08X,%08X" $label [lindex $values 0] [lindex $values 1] [lindex $values 2]]
    if {[lindex $values 0] != $expected} { error "V109A_${label}_UNEXPECTED expected=[format 0x%08X $expected] got=[format 0x%08X [lindex $values 0]]" }
    return [lindex $values 0]
}
proc v109a_wait_sba_idle {label} {
    for {set i 0} {$i < 50} {incr i} {
        set s [v109a_dread 0x38]
        echo [format "V109A_SBCS label=%s_POLL_%02d value=0x%08X" $label $i $s]
        # During a legitimate transaction sbbusy (bit 21) may be 1; only
        # sbbusyerror (bit 22) or sberror[14:12] are fatal while polling.
        if {$s & 0x00407000} { error "V109A_SBA_ERROR_AFTER_WRITE value=[format 0x%08X $s]" }
        if {($s & 0x00200000) == 0} { return $s }
        sleep 1
    }
    error "V109A_SBA_BUSY_TIMEOUT label=$label"
}

set rc [catch {
    set initlog [capture {init}]
    echo "V109A_INIT_BEGIN"; echo $initlog; echo "V109A_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $initlog]} { error "V109A_JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu"} { error "V109A_TAP_NOT_UNIQUE names=[jtag names]" }
    if {![regexp -nocase {0x1e200a6f} $initlog]} { error "V109A_IDCODE_MISMATCH" }
    if {![regexp -- $::v109a_probe_serial $initlog]} { error "V109A_PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]
    echo "V109A_CPU_STATE=$cpu"
    if {$cpu ne "halted"} { error "V109A_CPU_NOT_ALREADY_HALTED; no halt request in this stage" }
    set dm [v109a_dread 0x11]
    echo [format "V109A_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "V109A_DMSTATUS_NOT_HALTED" }
    v109a_sb_status PREFLIGHT
    v109a_triplet 0x4002180c PERI_CLKEN 0
    v109a_triplet 0x40021810 PERI_RST 0

    # Switch SBA to 32-bit write mode, then issue exactly one SBDATA0 write.
    v109a_dmi_write 0x38 0x20040404 WRITE_MODE
    v109a_sb_status WRITE_MODE_READY
    v109a_dmi_write 0x39 0x4002180c WRITE_ADDRESS_PERI_CLKEN
    v109a_sb_status WRITE_READY
    incr ::v109a_target_write_count
    echo "V109A_TARGET_MMIO_WRITE_ATTEMPT addr=0x4002180C value=0x00000001 count=1"
    v109a_dmi_write 0x3c 0x00000001 TARGET_PERI_CLKEN_WRITE
    v109a_wait_sba_idle PERI_CLKEN_WRITE

    v109a_triplet 0x4002180c PERI_CLKEN_POSTWRITE 1
    v109a_triplet 0x40021810 PERI_RST_POSTWRITE 0
    foreach {label addr} {GPIOB_ODR 0x40000100 GPIOB_DIR 0x40000104 GPIOB_IDR 0x40000150 GPIOB_OSOD 0x40000158 GPIOB_PUPD 0x4000015c GPIOB_AFR1 0x40000168 GPIOB_AFR2 0x4000016c} {
        v109a_read $addr $label
    }
    set ::v109a_gpio_status "READ_CLOCK_ON"
    set ::v109a_status "PASS_GPIO_CLOCK_ON_AND_SNAPSHOT"
} err]
if {$rc} { set ::v109a_status "FAIL_OR_UNKNOWN"; echo "V109A_ERROR=$err" }
set final_sb_rc [catch {v109a_sb_status FINAL} final_sb]
echo [format "V109A_FINAL_SBCS rc=%d value=%s" $final_sb_rc $final_sb]
set final_dm_rc [catch {v109a_dread 0x11} final_dm]
echo [format "V109A_FINAL_DMSTATUS rc=%d value=%s" $final_dm_rc $final_dm]
echo [format "V109A_RESULT=%s TARGET_MMIO_WRITE_COUNT=%d GPIO=%s" $::v109a_status $::v109a_target_write_count $::v109a_gpio_status]
echo "V109A_COMPLETE"
shutdown
