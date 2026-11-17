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

proc run_access_window {index mode} {
    set original_before [read_word 0x2000F010]
    set copy_before [read_word 0x2000F110]
    set slots 20
    set slot_ms 70
    set start [ms]
    set transactions 0
    set overruns 0
    for {set i 0} {$i < $slots} {incr i} {
        set alternate [expr {$i % 2}]
        switch -- $mode {
            quiet {}
            count {
                read_word [expr {$alternate ? 0x2000F110 : 0x2000F010}]
                incr transactions
            }
            sram {
                set value [read_word [expr {$alternate ? 0x2000F104 : 0x2000F004}]]
                if {$value != 8} {error "FIXED_WORD_CHANGED index=$index slot=$i value=$value"}
                incr transactions
            }
            dmi {
                set raw [capture {riscv dmi_read 0x11}]
                if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> word]} {error "DMSTATUS_PARSE <$raw>"}
                scan $word %x dm
                if {($dm & 0xf80) != 0xc80} {error "UNEXPECTED_DMSTATUS $word"}
                incr transactions
            }
            default {error "UNKNOWN_ACCESS_MODE $mode"}
        }
        set wait_ms [expr {$start + ($i + 1) * $slot_ms - [ms]}]
        if {$wait_ms > 0} {
            sleep $wait_ms busy
        } elseif {$wait_ms < 0} {
            incr overruns
        }
    }
    set elapsed [expr {[ms] - $start}]
    set original_after [read_word 0x2000F010]
    set copy_after [read_word 0x2000F110]
    echo "ACCESS_WINDOW $index $mode $elapsed $transactions $overruns $original_before $original_after $copy_before $copy_after"
}

proc compare_access_types {} {
    poll off
    check_controls
    set i 0
    foreach mode {quiet count dmi sram count quiet sram dmi sram dmi count quiet dmi sram quiet count} {
        run_access_window $i $mode
        incr i
    }
    check_controls
}

if {[catch {compare_access_types} message]} {
    echo "ACCESS_ERROR=$message"
} else {
    echo ACCESS_COMPLETE
}
shutdown
