from pathlib import Path
import tkinter

source = Path(__file__).with_name("wait_test.tcl").read_text(encoding="utf-8")
mock = r"""
set words {57414931 00000000 53454152 00000000 57410001 00000000 00000000 00000000}
set events {}; set writes {}
proc echo {arg} {lappend ::events $arg}
proc shutdown {} {}
proc jtag {what} {return riscv.cpu}
proc riscv.cpu {what} {return running}
proc sleep {ms} {}
proc capture {command} {
    switch -- [lindex $command 0] {
        init {return "Info : CMSIS-DAP: Serial# = 07000001006700343500000a4e57354aa5a5a5a597969908\nInfo : JTAG tap: riscv.cpu tap/device found: 0x1e200a6f"}
        riscv {
            if {[lindex $command 2] eq "0x11"} {return "0x00430c82\n"}
            return "0x20040404\n"
        }
        mdw {
            set addr [lindex $command 1]
            set idx [expr {($addr - 0x2000F000) / 4}]
            return "$addr: [lindex $::words $idx]\n\n"
        }
        mww {
            if {[lindex $command 1] ne "0x2000F014"} {error WRONG_ADDRESS}
            set value [lindex $command 2]
            lappend ::writes $value
            if {$value == 0x53454152} {
                lset ::words 3 53454152
                lset ::words 4 5741600D
                lset ::words 5 00000000
                lset ::words 6 00000002
            } elseif {!$::lost_write} {
                lset ::words 5 53454153
            }
            return ""
        }
        default {error "Unexpected command: $command"}
    }
}
"""

for name, setup, desired, expected_writes in [
    ("normal", "set lost_write 0", "NORMAL_WAIT_AND_EXIT", "0x53454153,0x53454152"),
    ("early", "set lost_write 0; lset words 4 5741FA11", "EXITED_BEFORE_HOST_TOKEN", ""),
    ("lost_wrong_token", "set lost_write 1", "WRONG_TOKEN_WAIT_NOT_CONFIRMED", "0x53454153"),
]:
    interp = tkinter.Tcl()
    interp.eval(mock)
    interp.eval(setup)
    interp.eval(source)
    outcome = interp.eval("lindex $events end")
    writes = interp.eval("join $writes ,")
    assert outcome == f"WAIT_OUTCOME={desired}", outcome
    assert writes == expected_writes, (writes, expected_writes)
    print(f"PASS {name} outcome={desired} writes={writes or 'none'}")
