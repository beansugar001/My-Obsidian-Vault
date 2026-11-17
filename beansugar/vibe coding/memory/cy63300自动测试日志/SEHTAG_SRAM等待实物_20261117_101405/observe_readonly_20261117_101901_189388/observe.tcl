set startup [capture {init}]
echo $startup
if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0} $startup]} {
    error JTAG_INIT_ERROR
}
set taps [regexp -all -inline {JTAG tap:\s+(\S+)\s+tap/device found:\s*(0x[0-9a-fA-F]+)} $startup]
if {[llength $taps] != 3 || [lindex $taps 1] ne "riscv.cpu" ||
    [expr {[lindex $taps 2]}] != 0x1e200a6f || [jtag names] ne "riscv.cpu"} {
    error TAP_IDCODE_FAIL
}
set probes [regexp -all -inline {Serial#\s*=\s*(\S+)} $startup]
if {[llength $probes] != 2 || [lindex $probes 1] ne "07000001006700343500000a4e57354aa5a5a5a597969908"} {
    error PROBE_SERIAL_FAIL
}
if {[riscv.cpu curstate] ne "running"} { error HART_NOT_RUNNING }
echo "CPU_STATE=running"
dump_image "$::env(WAIT_OBSERVE_0)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_1)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_2)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_3)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_4)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_5)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_6)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_OBSERVE_7)" 0x2000F000 0x20
sleep 100
dump_image "$::env(WAIT_IMAGE)" 0x00000000 0xAC
echo WAIT_READONLY_COMPLETE
shutdown
