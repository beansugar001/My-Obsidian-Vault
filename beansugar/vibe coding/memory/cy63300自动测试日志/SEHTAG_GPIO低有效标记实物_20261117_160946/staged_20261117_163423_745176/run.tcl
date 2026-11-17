set startup [capture {init; poll off}]
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
debug_level 3
proc read_word {addr} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr] $out -> value]} {
        error "READ_PARSE <$out>"
    }
    scan $value %x word
    return [expr {$word & 0xffffffff}]
}

proc wait_step {gate} {
    set start [ms]
    while {[ms] - $start < 120000} {
        if {[file exists "$::env(GPIO_GATE)/stop"]} {return 0}
        if {[file exists "$::env(GPIO_GATE)/$gate"]} {return 1}
        after 100
    }
    puts STEP_EXPIRED
    return 0
}

proc staged_read {} {
    # The Jim timer and markers avoid the OpenOCD command callbacks while waiting.
    puts STEP_INIT_COMPLETE
    if {![wait_step dmstatus]} {return}
    puts STEP_DMSTATUS_BEGIN
    set raw [capture {riscv dmi_read 0x11}]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> hex]} {error "DMSTATUS_PARSE <$raw>"}
    scan $hex %x status
    puts [format "STEP_DMSTATUS_COMPLETE 0x%08X" $status]
    if {($status & 0xf80) != 0xc80} {error HART_NOT_RUNNING}
    if {![wait_step sram]} {return}
    puts STEP_SRAM_BEGIN
    puts [format "STEP_SRAM_COMPLETE 0x%08X" [read_word 0x2000F010]]
    wait_step finish
}
if {[catch {staged_read} detail]} {puts "STEP_ERROR=$detail"}
puts STEP_SESSION_END
shutdown
