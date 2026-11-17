proc dmi_read_value {addr} {
    set raw [capture [format "riscv dmi_read 0x%X" $addr]]
    foreach line [split $raw "\n"] {
        if {[regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $line -> hex]} {
            scan $hex %x value
            return [expr {$value & 0xffffffff}]
        }
    }
    error "DMI_READ_PARSE <$raw>"
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
    echo "MATCHED_BEGIN $index $mode"
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
    echo "MATCHED_END $index $mode"
    set after [read_word 0x2000F010]
    set after_copy [read_word 0x2000F110]
    echo "MATCHED_WINDOW $index $mode $elapsed $ops $overruns $before $after $before_copy $after_copy"
    if {$overruns != 0} {error WINDOW_OVERRUN}
}

proc matched_access {} {
    poll off
    check_controls
    debug_level 3
    set i 0
    foreach mode {quiet dmi sba dmi sba quiet sba quiet dmi} {
        matched_window $i $mode
        incr i
    }
    debug_level 2
    check_controls
}

if {[catch {matched_access} message]} {
    echo "MATCHED_ERROR=$message"
} else {
    echo MATCHED_COMPLETE
}
shutdown
