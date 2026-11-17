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
proc read_word {addr} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr] $out -> value]} {
        error "READ_PARSE <$out>"
    }
    scan $value %x word
    return [expr {$word & 0xffffffff}]
}

proc check_controls {} {
    set out [capture {riscv dmi_read 0x11}]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $out -> value]} {
        error "DMSTATUS_PARSE <$out>"
    }
    scan $value %x dm
    if {($dm & 0xF80) != 0xC80 || [riscv.cpu curstate] ne "running"} {
        error "HART_NOT_RUNNING"
    }
    if {[read_word 0x2000F000] != 0x52544000 || [read_word 0x2000F004] != 8 ||
        [read_word 0x2000F104] != 8 || [read_word 0x2000F02C] != 0x52547000 ||
        [read_word 0x2000F030] != 0x53454000} {
        error "CONTROL_WORD_MISMATCH"
    }
}

proc run_window {index mode duration} {
    set before [read_word 0x2000F010]
    set before_copy [read_word 0x2000F110]
    set start [ms]
    set reads 0
    if {$mode eq "quiet"} {
        sleep $duration busy
    } else {
        while {[ms] - $start < $duration} {
            read_word 0x2000F010
            read_word 0x2000F110
            incr reads 2
        }
    }
    set elapsed [expr {[ms] - $start}]
    set after [read_word 0x2000F010]
    set after_copy [read_word 0x2000F110]
    echo [format "CADENCE_WINDOW %d %s %d %d %d %d %d %d" $index $mode $elapsed $reads $before $after $before_copy $after_copy]
}

proc cadence {} {
    poll off
    check_controls
    set i 0
    foreach mode {quiet active active quiet quiet active} {
        run_window $i $mode 1200
        incr i
    }
    check_controls
}

if {[catch {cadence} message]} {
    echo "CADENCE_ERROR=$message"
} else {
    echo CADENCE_COMPLETE
}
shutdown
