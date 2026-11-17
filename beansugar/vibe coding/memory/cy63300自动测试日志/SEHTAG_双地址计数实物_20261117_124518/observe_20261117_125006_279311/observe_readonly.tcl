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

proc read_word {sample field addr} {
    set output [capture [format "mdw 0x%08X" $addr]]
    set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
    if {![regexp -nocase $pattern $output -> value]} {error "READ_PARSE <$output>"}
    echo [format "MIRROR_WORD %02d %s %08X %s" $sample $field $addr $value]
}

dump_image "$::env(MIRROR_RUN)/mailbox_before.bin" 0x2000F000 0x34
for {set i 0} {$i < 12} {incr i} {
    if {[riscv.cpu curstate] ne "running"} {error HART_NOT_RUNNING}
    if {$i % 2 == 0} {
        set addresses {second 0x2000F010 second_copy 0x2000F110 second 0x2000F010}
    } else {
        set addresses {second_copy 0x2000F110 second 0x2000F010 second_copy 0x2000F110}
    }
    foreach {field addr} $addresses {
        read_word $i $field $addr
    }
    foreach {field addr} {first 0x2000F004 first_copy 0x2000F104 done 0x2000F02C scratch 0x2000F030} {
        read_word $i $field $addr
    }
    sleep 120
}
dump_image "$::env(MIRROR_RUN)/mailbox_after.bin" 0x2000F000 0x34
dump_image "$::env(MIRROR_RUN)/startup.bin" 0x00000000 0x174
echo MIRROR_SAMPLES_COMPLETE
shutdown
