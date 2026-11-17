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
proc read_word {addr} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr] $out -> value]} {
        error "READ_PARSE <$out>"
    }
    scan $value %x word
    return [expr {$word & 0xffffffff}]
}
proc read_idle_sbcs {label} {
    set raw [capture {riscv dmi_read 0x38}]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> hex]} {error "SBCS_PARSE <$raw>"}
    scan $hex %x value
    puts [format "SBCS_%s 0x%08X" $label $value]
    if {($value & 0x00607000) != 0} {error "SBCS_BUSY_OR_ERROR $label"}
    return $value
}
debug_level 3
puts "MATCHED_INIT [ms]"
after 5000
puts "MATCHED_SLOT_BEGIN [ms]"
set slot_start [ms]
if {0} {
    set raw [capture {riscv dmi_read 0x11}]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> hex]} {error "DMSTATUS_PARSE <$raw>"}
    scan $hex %x status
    puts [format "MATCHED_DMSTATUS 0x%08X" $status]
    if {($status & 0xf80) != 0xc80} {error HART_NOT_RUNNING}
}
puts "MATCHED_SLOT_END [ms]"
set remaining [expr {5000 - ([ms] - $slot_start)}]
if {$remaining <= 0} {error MATCHED_SLOT_OVERRUN}
after $remaining
puts "MATCHED_SRAM_BEGIN [ms]"
if {1} {
    
    set original_mode [expr {[read_idle_sbcs BEFORE] & 0x001f8000}]
    if {$original_mode != 0 && $original_mode != 0x00040000} {
        error [format "UNEXPECTED_INITIAL_SBCS_MODE 0x%08X" $original_mode]
    }
    set value [read_word 0x2000F010]
    puts [format "SRAM_ONLY_READ_COMPLETE 0x%08X" $value]
    if {([read_idle_sbcs AFTER_READ] & 0x001f8000) != 0x00150000} {
        error UNEXPECTED_POST_READ_SBCS_MODE
    }
    riscv dmi_write 0x38 $original_mode
    if {([read_idle_sbcs RESTORED] & 0x001f8000) != $original_mode} {
        error SBCS_RESTORE_MISMATCH
    }
    puts SBCS_RESTORE_COMPLETE

}
puts "MATCHED_SRAM_END [ms]"
after 30000
puts "MATCHED_WAIT_EXIT [ms]"
set deadline_start [ms]
while {![file exists "$::env(GPIO_GATE)/finish"]} {
    if {[ms] - $deadline_start >= 120000} {error MATCHED_EXIT_GATE_EXPIRED}
    after 100
}
puts "MATCHED_EXIT [ms]"
shutdown
