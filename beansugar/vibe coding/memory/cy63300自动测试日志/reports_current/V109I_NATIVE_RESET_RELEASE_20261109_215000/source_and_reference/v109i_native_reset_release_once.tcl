# V109I: one native OpenOCD mww recovery attempt after the custom SBA release failed.
set ::v109i_status "INCOMPLETE_OR_UNKNOWN"
set ::v109i_halt_count 0
set ::v109i_target_write_count 0
proc v109i_dread {r} {
    set o [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} { error "DMI_READ_PARSE_FAIL reg=$r raw=<$o>" }
    scan $x %x v
    return [expr {$v & 0xffffffff}]
}
proc v109i_mdw {addr label} {
    set o [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase {0x[0-9a-f]+:\s*([0-9a-f]+)} $o -> x]} { error "MDW_PARSE_FAIL label=$label raw=<$o>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V109I_MDW label=%s addr=0x%08X value=0x%08X" $label $addr $v]
    return $v
}
set rc [catch {
    set init [capture {init}]
    echo "V109I_INIT_BEGIN"; echo $init; echo "V109I_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_MISMATCH" }
    if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "PROBE_SERIAL_MISMATCH" }
    set cpu [riscv.cpu curstate]
    echo "V109I_CPU_INITIAL=$cpu"
    if {$cpu eq "running"} { echo "V109I_HALT_REQUEST=once"; halt 2000; incr ::v109i_halt_count; set cpu [riscv.cpu curstate] }
    echo "V109I_CPU_FINAL=$cpu"
    if {$cpu ne "halted" || $::v109i_halt_count > 1} { error "CPU_NOT_HALTED" }
    set dm [v109i_dread 0x11]
    echo [format "V109I_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x300) != 0x300 || ($dm & 0xc00) != 0} { error "DMSTATUS_NOT_HALTED" }
    set clk [v109i_mdw 0x4002180c PERI_CLKEN]
    set rst [v109i_mdw 0x40021810 PERI_RST_PRE]
    if {$clk != 0x21 || $rst != 0x20} { error [format "PRECONDITION_MISMATCH CLKEN=0x%08X RST=0x%08X" $clk $rst] }
    echo "V109I_TARGET_MMIO_WRITE_ATTEMPT addr=0x40021810 value=0x00000000 count=1 method=OpenOCD_mww"
    incr ::v109i_target_write_count
    mww 0x40021810 0x00000000
    sleep 20
    set vals {}
    foreach n {1 2 3} {
        lappend vals [v109i_mdw 0x40021810 "PERI_RST_POST_$n"]
        if {$n < 3} { sleep 20 }
    }
    echo [format "V109I_PERI_RST_TRIPLE=0x%08X,0x%08X,0x%08X" [lindex $vals 0] [lindex $vals 1] [lindex $vals 2]]
    if {[lindex $vals 0] == 0 && [lindex $vals 1] == 0 && [lindex $vals 2] == 0} {
        set ::v109i_status "PASS_RESET_RELEASED_NATIVE_MWW"
    } elseif {[lindex $vals 0] == 0x20 && [lindex $vals 1] == 0x20 && [lindex $vals 2] == 0x20} {
        set ::v109i_status "FAIL_RESET_STILL_ASSERTED"
    } else {
        set ::v109i_status "UNKNOWN_RESET_READBACK_UNSTABLE"
    }
} err]
if {$rc} { set ::v109i_status "FAIL_OR_UNKNOWN"; echo "V109I_ERROR=$err" }
set sf [catch {set sb [v109i_dread 0x38]; echo [format "V109I_FINAL_SBCS=0x%08X" $sb]} se]
echo [format "V109I_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v109i_status $::v109i_halt_count $::v109i_target_write_count]
echo "V109I_COMPLETE"
shutdown
