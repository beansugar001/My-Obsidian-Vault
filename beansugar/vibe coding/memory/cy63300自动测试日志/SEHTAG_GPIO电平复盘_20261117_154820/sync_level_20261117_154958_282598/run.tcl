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

proc gpio_snapshot {label} {
    set fields {}
    foreach addr {0x40000200 0x40000204 0x2000F004 0x2000F010 0x2000F110 0x2000F02C} {
        lappend fields [read_word $addr]
    }
    echo [format "SYNC_STATE %s %08X %08X %08X %08X %08X %08X" $label {*}$fields]
}

proc synchronized_read {} {
    poll off
    if {[read_word 0x4002180c] != 1 || [read_word 0x2000F000] != 0x52544000} {
        error "WRONG_IMAGE_OR_CLOCK"
    }
    gpio_snapshot INITIAL
    sleep 5000 busy
    gpio_snapshot BEFORE_ACTIVE
    set start [ms]
    set count 0
    while {[ms] - $start < 10000} {
        read_word 0x2000F010
        read_word 0x2000F110
        incr count 2
    }
    echo "SYNC_ACTIVE_READS $count"
    gpio_snapshot AFTER_ACTIVE
    sleep 5000 busy
    gpio_snapshot FINAL
}

if {[catch {synchronized_read} detail]} {
    echo "SYNC_ERROR=$detail"
} else {
    echo SYNC_COMPLETE
}
shutdown
