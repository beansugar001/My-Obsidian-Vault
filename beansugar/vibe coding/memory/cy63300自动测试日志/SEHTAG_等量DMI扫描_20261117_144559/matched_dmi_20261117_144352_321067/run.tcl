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

proc dmi_read_value {addr} {
    set raw [capture [format "riscv dmi_read 0x%X" $addr]]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> hex]} {error "DMI_READ_PARSE <$raw>"}
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc dmi_configure_read {addr value} {
    if {!(($addr == 0x38 && ($value == 0x00140000 || $value == 0x00040000)) ||
          ($addr == 0x39 && ($value == 0x2000F004 || $value == 0x2000F02C)))} {
        error "UNEXPECTED_SBA_CONFIGURATION"
    }
    set raw [capture [format "riscv dmi_write 0x%X 0x%08X" $addr $value]]
    if {[regexp -nocase {error|fail|timeout} $raw]} {error "DMI_CONFIGURATION <$raw>"}
}

proc sba_idle {label} {
    set value [dmi_read_value 0x38]
    if {$value & 0x00607000} {error [format "SBA_BUSY_OR_ERROR %s 0x%08X" $label $value]}
    return $value
}

proc fixed_sba_read {slot} {
    if {$slot % 2 == 0} {
        set address 0x2000F004
        set expected 8
    } else {
        set address 0x2000F02C
        set expected 0x52547000
    }
    sba_idle BEFORE
    dmi_configure_read 0x38 0x00140000
    if {([sba_idle READ_MODE] & 0x001F8000) != 0x00140000} {error "SBA_READ_MODE_MISMATCH"}
    dmi_configure_read 0x39 $address
    sba_idle BEFORE_DATA
    set value [dmi_read_value 0x3c]
    sba_idle AFTER_DATA
    dmi_configure_read 0x38 0x00040000
    if {([sba_idle AFTER_MODE] & 0x001F8000) != 0x00040000} {error "SBA_IDLE_MODE_MISMATCH"}
    if {$value != $expected} {error [format "SBA_DATA_MISMATCH addr=0x%08X actual=0x%08X" $address $value]}
}

proc matched_window {index mode} {
    set before [read_word 0x2000F010]
    set before_copy [read_word 0x2000F110]
    set initial_flush [jtag flush_count]
    set start [ms]
    set overruns 0
    set ops 0
    for {set slot 0} {$slot < 6} {incr slot} {
        switch -- $mode {
            quiet {}
            dmi {
                for {set i 0} {$i < 9} {incr i} {
                    if {([dmi_read_value 0x11] & 0xF80) != 0xC80} {error HART_NOT_RUNNING}
                }
                incr ops 9
            }
            sba {
                fixed_sba_read $slot
                incr ops 9
            }
            default {error "UNKNOWN_WINDOW"}
        }
        set remaining [expr {$start + ($slot + 1) * 350 - [ms]}]
        if {$remaining > 0} {
            sleep $remaining busy
        } elseif {$remaining < 0} {
            incr overruns
        }
    }
    set elapsed [expr {[ms] - $start}]
    set flushes [expr {[jtag flush_count] - $initial_flush}]
    set after [read_word 0x2000F010]
    set after_copy [read_word 0x2000F110]
    echo "MATCHED_WINDOW $index $mode $elapsed $ops $flushes $overruns $before $after $before_copy $after_copy"
    if {$flushes != 2 * $ops || $overruns != 0} {error WINDOW_NOT_MATCHED}
}

proc matched_access {} {
    poll off
    check_controls
    set i 0
    foreach mode {quiet dmi sba dmi sba quiet sba quiet dmi} {
        matched_window $i $mode
        incr i
    }
    check_controls
}

if {[catch {matched_access} message]} {
    echo "MATCHED_ERROR=$message"
} else {
    echo MATCHED_COMPLETE
}
shutdown
