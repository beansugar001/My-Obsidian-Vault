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

proc word {label addr} {
    set raw [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr] $raw -> hex]} {
        error "READ_PARSE <$raw>"
    }
    scan $hex %x value
    echo [format "LEVEL_WORD %s %08X %08X" $label $addr $value]
    return $value
}
proc inspect {} {
    for {set i 0} {$i < 4} {incr i} {
        set clk [word "CLK_$i" 0x4002180c]
        word "RST_$i" 0x40021810
        if {($clk & 1) != 0} {
            foreach {name addr} {DIR 0x40000204 ODR 0x40000200 IDR 0x40000250 OSOD 0x40000258 PUPD 0x4000025C AFR1 0x40000268 AFR2 0x4000026C} {word "${name}_$i" $addr}
        }
        dump_image [format "%s/mailbox_%d.bin" $::env(GPIO_RUN) $i] 0x2000F000 0x34
        word "OBS_COUNT_COPY_$i" 0x2000F110
        sleep 130
    }
    dump_image "$::env(GPIO_RUN)/image.bin" 0x0 0x1F0
    echo GPIO_READBACK_COMPLETE
}
if {[catch {inspect} detail]} {echo "GPIO_READBACK_ERROR=$detail"}
shutdown
