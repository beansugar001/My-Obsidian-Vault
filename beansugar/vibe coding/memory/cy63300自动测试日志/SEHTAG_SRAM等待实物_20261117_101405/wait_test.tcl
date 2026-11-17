proc read_hex {raw pattern} {
    if {![regexp -nocase $pattern $raw -> value]} {error "READ_PARSE <$raw>"}
    scan $value %x result
    return [expr {$result & 0xffffffff}]
}

proc check_hart {label} {
    set pattern {^\s*0x([0-9a-f]+)\s*$}
    set dm [read_hex [capture {riscv dmi_read 0x11}] $pattern]
    set sb [read_hex [capture {riscv dmi_read 0x38}] $pattern]
    set state [riscv.cpu curstate]
    echo [format "WAIT_STATUS_%s hart=%s DMSTATUS=0x%08X SBCS=0x%08X" $label $state $dm $sb]
    if {$state ne "running" || ($dm & 0xF80) != 0xC80 || ($sb & 0x00607000) != 0} {error UNEXPECTED_HART_OR_SBA}
}

proc mailbox {label} {
    set words {}
    for {set addr 0x2000F000} {$addr < 0x2000F020} {incr addr 4} {
        set raw [capture [format "mdw 0x%08X" $addr]]
        lappend words [read_hex $raw [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]]
    }
    echo [format "WAIT_MAILBOX_%s magic=%08X first=%08X compare=%08X exit=%08X stage=%08X token=%08X route=%08X xor=%08X" $label {*}$words]
    return $words
}

proc write_token {value} {
    if {$value != 0x53454153 && $value != 0x53454152} {error TOKEN_DENIED}
    echo [format "WAIT_TOKEN_REQUEST value=0x%08X" $value]
    set raw [capture [format "mww 0x2000F014 0x%08X" $value]]
    if {$raw ne ""} {echo $raw}
    if {[regexp -nocase {Error:|failed|timeout} $raw]} {error SRAM_WRITE_ERROR}
}

proc perform {} {
    set startup [capture {init}]
    echo $startup
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0} $startup]} {error JTAG_INIT_ERROR}
    set taps [regexp -all -inline {JTAG tap:\s+(\S+)\s+tap/device found:\s*(0x[0-9a-fA-F]+)} $startup]
    if {[llength $taps] != 3 || [lindex $taps 1] ne "riscv.cpu" ||
        [expr {[lindex $taps 2]}] != 0x1e200a6f || [jtag names] ne "riscv.cpu"} {error TAP_IDCODE_FAIL}
    set probes [regexp -all -inline {Serial#\s*=\s*(\S+)} $startup]
    if {[llength $probes] != 2 || [lindex $probes 1] ne "07000001006700343500000a4e57354aa5a5a5a597969908"} {error PROBE_SERIAL_FAIL}

    check_hart BEFORE
    set a [mailbox BEFORE_A]
    sleep 100
    if {$a ne [mailbox BEFORE_B]} {error UNSTABLE_INITIAL_MAILBOX}
    lassign $a magic first compare last stage token route diff
    if {$magic != 0x57414931 || $compare != 0x53454152} {error UNEXPECTED_IMAGE_OR_COMPARE}
    if {$stage == 0x5741600D || $stage == 0x5741FA11} {
        return EXITED_BEFORE_HOST_TOKEN
    }
    if {$stage != 0x57410001 || $token != 0} {error PROBE_NOT_WAITING}
    check_hart BEFORE_WRONG_TOKEN
    write_token 0x53454153
    sleep 200
    check_hart AFTER_WRONG_TOKEN
    set wrong [mailbox WRONG]
    if {[lindex $wrong 4] != 0x57410001 || [lindex $wrong 5] != 0x53454153 ||
        [lrange $wrong 0 2] ne [lrange $a 0 2]} {
        return WRONG_TOKEN_WAIT_NOT_CONFIRMED
    }
    write_token 0x53454152
    sleep 200
    check_hart AFTER_CORRECT_TOKEN
    set final [mailbox FINAL_A]
    sleep 100
    if {$final ne [mailbox FINAL_B]} {return UNSTABLE_FINAL_MAILBOX}
    lassign $final final_magic final_first final_compare final_last final_stage final_token final_route final_diff
    if {$final_magic == $magic && $final_first == $first && $final_compare == $compare &&
        $final_last == 0x53454152 && $final_stage == 0x5741600D && $final_token == 0 &&
        $final_route == 2 && $final_diff == 0} {return NORMAL_WAIT_AND_EXIT}
    return CORRECT_TOKEN_EXIT_NOT_CONFIRMED
}

if {[catch {perform} result]} {
    echo "WAIT_ERROR=$result"
} else {
    echo "WAIT_OUTCOME=$result"
}
shutdown
