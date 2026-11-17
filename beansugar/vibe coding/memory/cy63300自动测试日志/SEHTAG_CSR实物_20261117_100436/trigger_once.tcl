proc read_dmi {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> value]} {error "DMI_READ_PARSE <$raw>"}
    scan $value %x result
    return [expr {$result & 0xffffffff}]
}

proc read_word {addr} {
    set raw [capture [format "mdw 0x%08X" $addr]]
    set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
    if {![regexp -nocase $pattern $raw -> value]} {error "MEMORY_READ_PARSE <$raw>"}
    scan $value %x result
    return [expr {$result & 0xffffffff}]
}

proc read_mailbox {label} {
    set words {}
    foreach addr {0x2000F000 0x2000F004 0x2000F008 0x2000F00C 0x2000F010 0x2000F014} {
        lappend words [read_word $addr]
    }
    echo [format "SEHTAG_MAILBOX_%s magic=%08X initial=%08X enabled=%08X restored=%08X result=%08X trigger=%08X" $label {*}$words]
    return $words
}

proc check_status {label} {
    set dm [read_dmi 0x11]
    set sb [read_dmi 0x38]
    echo [format "SEHTAG_STATUS_%s hart=%s DMSTATUS=0x%08X SBCS=0x%08X" $label [riscv.cpu curstate] $dm $sb]
    if {[riscv.cpu curstate] ne "running" || ($dm & 0xF80) != 0xC80 || ($sb & 0x00607000) != 0} {
        error "UNEXPECTED_HART_OR_SBA_STATE"
    }
}

proc perform {} {
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

    check_status BEFORE
    foreach label {READY_A READY_B} {
        set words [read_mailbox $label]
        if {[lindex $words 0] != 0x53454833 || [lindex $words 4] != 0 || [lindex $words 5] != 0} {
            error PROBE_NOT_WAITING
        }
    }
    check_status IMMEDIATE_PRE_WRITE
    echo "SEHTAG_ARM_REQUEST addr=0x2000F014 value=0x53454152"
    set raw [capture {mww 0x2000F014 0x53454152}]
    if {$raw ne ""} {echo $raw}
    if {[regexp -nocase {Error:|failed|timeout} $raw]} {error SRAM_WRITE_ERROR}
    sleep 200
    check_status AFTER
    set a [read_mailbox RESULT_A]
    sleep 100
    set b [read_mailbox RESULT_B]
    if {$a ne $b || [lindex $a 0] != 0x53454833} {return UNSTABLE_RESULT}
    lassign $a magic initial enabled restored result token
    if {$initial == 0 && $enabled == 1 && $restored == 0 && $result == 0x5345600D && $token == 0} {
        return CSR_TOGGLE_RESTORED
    }
    if {$initial == 0 && $enabled == 0 && $restored == 0 && $result == 0x5345FA11 && $token == 0} {
        return CSR_READBACK_ZERO
    }
    if {$result == 0x53450001 && $token == 0} {return TRIGGER_CONSUMED_NO_COMPLETION}
    if {$result == 0 && $token == 0} {return TRIGGER_NOT_OBSERVED}
    if {$result == 0 && $token == 0x53454152} {return TRIGGER_NOT_CONSUMED}
    return UNEXPECTED_MAILBOX
}

if {[catch {perform} result]} {
    echo "SEHTAG_ERROR=$result"
} else {
    echo "SEHTAG_OUTCOME=$result"
}
shutdown
