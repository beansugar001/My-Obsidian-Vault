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

for {set i 0} {$i < 8} {incr i} {
    if {[riscv.cpu curstate] ne "running"} {error HART_NOT_RUNNING}
    dump_image [format "%s/mailbox_%02d.bin" $::env(INSTRUCTION_LOG) $i] 0x2000F000 0x28
    for {set addr 0x2000F000} {$addr < 0x2000F028} {incr addr 4} {
        set output [capture [format "mdw 0x%08X" $addr]]
        set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
        if {![regexp -nocase $pattern $output -> value]} {error "BAD_READ $output"}
        echo [format "INSTRUCTION_WORD %02d %08X %s" $i $addr $value]
    }
    sleep 120
}
dump_image [format "%s/startup.bin" $::env(INSTRUCTION_LOG)] 0x0 0xC4
echo INSTRUCTION_SAMPLES_COMPLETE
shutdown
