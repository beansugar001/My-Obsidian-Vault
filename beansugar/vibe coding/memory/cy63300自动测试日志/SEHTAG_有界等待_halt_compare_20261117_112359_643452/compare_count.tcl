proc status {expected label} {
    foreach {addr name} {0x11 dm 0x38 sb} {
        set raw [capture [format "riscv dmi_read 0x%X" $addr]]
        if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> value]} {error "DMI_PARSE <$raw>"}
        scan $value %x $name
    }
    set state [riscv.cpu curstate]
    echo [format "COMPARE_STATE %s %s DMSTATUS=%08X SBCS=%08X" $label $state $dm $sb]
    set expected_bits [expr {$expected eq "running" ? 0xC80 : 0x380}]
    if {$state ne $expected || ($dm & 0xF80) != $expected_bits || ($sb & 0x00607000)} {
        error "HART_OR_SBA_INVALID $label"
    }
}

proc sample {state} {
    for {set i 0} {$i < 8} {incr i} {
        status $state "${state}_$i"
        dump_image [format "%s/%s_%02d.bin" $::env(SEHTAG_CAPTURE) $state $i] 0x2000F000 0x34
        set raw [capture {mdw 0x2000F010}]
        if {![regexp -nocase {^\s*0x2000f010:\s+([0-9a-f]{8})\s*$} $raw -> word]} {
            error "STAGE_READ_PARSE <$raw>"
        }
        echo "COMPARE_STAGE $state $i $word"
        sleep 125
    }
    status $state "${state}_last"
}

proc compare_mailbox {} {
    set startup [capture {init}]
    echo $startup
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0} $startup]} {error JTAG_INIT_ERROR}
    set taps [regexp -all -inline {JTAG tap:\s+(\S+)\s+tap/device found:\s*(0x[0-9a-fA-F]+)} $startup]
    if {[llength $taps] != 3 || [lindex $taps 1] ne "riscv.cpu" ||
        [expr {[lindex $taps 2]}] != 0x1e200a6f || [jtag names] ne "riscv.cpu"} {error TAP_IDCODE_FAIL}
    set probes [regexp -all -inline {Serial#\s*=\s*(\S+)} $startup]
    if {[llength $probes] != 2 || [lindex $probes 1] ne "07000001006700343500000a4e57354aa5a5a5a597969908"} {error PROBE_SERIAL_FAIL}
    sample running
    set raw [capture {mdw 0x2000F000}]
    if {![regexp -nocase {^\s*0x2000f000:\s+4c575000\s*$} $raw]} {error "WRONG_MAILBOX <$raw>"}
    status running PRE_HALT
    echo COMPARE_HALT_REQUEST
    halt 2000
    sample halted
    for {set i 0} {$i < 3} {incr i} {
        if {[catch {capture {reg pc force}} output]} {echo "COMPARE_PC_QUERY_ERROR $output"; break}
        echo "COMPARE_PC $i <$output>"
    }
}

if {[catch {compare_mailbox} message]} {
    echo "COMPARE_ERROR=$message"
} else {
    echo COMPARE_COMPLETE
}
shutdown
