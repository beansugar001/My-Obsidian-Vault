# One halt request if needed, then only read DMSTATUS. No MMIO/memory access.
if {![info exists ::v114b_authorized] || $::v114b_authorized != 1} { error "V114B_AUTH_REQUIRED" }
set ::v114b_halt_count 0
set ::v114b_status "INCOMPLETE_OR_UNKNOWN"
set ::v114b_probe_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
set rc [catch {
    set il [capture {init}]
    echo "V114B_INIT_BEGIN"; echo $il; echo "V114B_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} { error "V114B_JTAG_INIT_ERROR" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il] || ![regexp $::v114b_probe_serial $il]} { error "V114B_IDCODE_OR_PROBE_FAIL" }
    set s [riscv.cpu curstate]
    echo "V114B_CPU_INITIAL=$s"
    if {$s eq "running"} { set h [capture {halt 2000}]; incr ::v114b_halt_count; echo "V114B_HALT=$h" }
    set s [riscv.cpu curstate]
    set dr [capture {riscv dmi_read 0x11}]
    if {![regexp -nocase {0x([0-9a-f]+)} $dr -> hex]} { error "V114B_DMSTATUS_PARSE_FAIL:$dr" }
    scan $hex %x dm
    echo "V114B_CPU_FINAL=$s"
    echo [format "V114B_DMSTATUS=0x%08X" $dm]
    if {$s eq "halted" && ($dm & 0x300) == 0x300 && ($dm & 0xC00) == 0} { set ::v114b_status "PASS_HALTED" } else { set ::v114b_status "FAIL_NOT_HALTED" }
} err]
if {$rc} { set ::v114b_status "FAIL_OR_UNKNOWN"; echo "V114B_ERROR=$err" }
echo [format "V114B_RESULT=%s HALT_COUNT=%d" $::v114b_status $::v114b_halt_count]
echo "V114B_COMPLETE"
shutdown

