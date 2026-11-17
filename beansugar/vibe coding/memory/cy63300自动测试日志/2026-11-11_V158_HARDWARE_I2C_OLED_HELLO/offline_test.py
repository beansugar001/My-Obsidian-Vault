
from pathlib import Path
import json
import struct
import tkinter
from decode_capture import BUS, CAPACITY, MAGIC, decode, verify

payloads = json.loads(Path("frames.json").read_text())["frames"]
tcl_source = Path("v158_hardware_hello.tcl").read_text().split("\nset rc [catch", 1)[0]
mock = r"""
set ::writes {}
set ::mctr 2
set ::tx 0
proc echo {args} {}
proc sleep {args} {}
proc capture {args} {
    return {riscv.cpu tap/device found: 0x1e200a6f
Serial# = 07000001006700343500000a4e57354aa5a5a5a597969908}
}
proc jtag {args} {return riscv.cpu}
proc riscv.cpu {args} {return halted}
proc v158_halted {} {}
proc v158_sba_idle {args} {return 0x20040404}
proc v158_expect {args} {}
proc v158_read {addr label} {return $::mctr}
proc v158_dmi_write {reg value} {
    if {$reg == 0x39} {set ::addr $value}
    if {$reg == 0x3C} {
        lappend ::writes [list $::addr $value]
        if {$::addr == 0x40002828} {set ::mctr $value} else {incr ::tx}
    }
}
proc v158_snapshot {phase i} {
    if {$phase eq "STOP"} {return {5 0 0}}
    if {$::fault eq "NACK" && $::tx == 2} {return {5 3 1}}
    if {$::fault eq "STALL" && $::tx == 2} {return {0x105 3 0}}
    return {5 3 0}
}
"""
expected = []
for payload in payloads:
    expected += [(0x40002828, 0), *((0x40002808, byte) for byte in payload), (0x40002828, 2)]
for fault in ("NONE", "NACK", "STALL"):
    tcl = tkinter.Tcl()
    tcl.eval(tcl_source)
    tcl.eval(mock)
    tcl.setvar("fault", fault)
    rc = int(tcl.eval("catch {v158_run} status"))
    writes = [tuple(int(x, 0) for x in tcl.splitlist(pair)) for pair in tcl.splitlist(tcl.eval("set writes"))]
    if fault == "NONE":
        assert rc == 0 and tcl.eval("set status") == "HELLO_FRAMES_DRAINED_STOP_IDLE"
        assert writes == expected
    else:
        assert rc == 1 and writes == expected[:3]
    print(f"PASS controller {fault}: {len(writes)} writes")

def capture(nack=False, stop=True):
    levels = BUS >> 8
    edges = []
    def pins(scl, sda):
        nonlocal levels
        new = scl | (sda << 1)
        if new != levels:
            levels = new
            edges.append(((len(edges) + 1) * 100 << 2) | new)
    for frame_index, payload in enumerate(payloads):
        pins(1, 0)
        pins(0, 0)
        for byte_index, byte in enumerate([0x78, *payload]):
            for bit in range(7, -1, -1):
                value = (byte >> bit) & 1
                pins(0, value)
                pins(1, value)
                pins(0, value)
            ack_bit = int(nack and frame_index == 2 and byte_index == 5)
            pins(0, ack_bit)
            pins(1, ack_bit)
            pins(0, ack_bit)
        pins(0, 0)
        pins(1, 0)
        if stop or frame_index + 1 < len(payloads):
            pins(1, 1)
    assert len(edges) < CAPACITY
    return struct.pack("<8I", MAGIC, 2, 1, len(edges), 1, BUS, levels << 8, 0) + struct.pack(
        f"<{CAPACITY}I", *edges, *([0] * (CAPACITY - len(edges)))
    )

for nack, stop, expected in ((False, True, True), (True, True, False), (False, False, False)):
    summary, edges = decode(capture(nack, stop))
    assert verify(summary, payloads) == expected
    print(f"PASS capture NACK={nack} STOP={stop}: {len(edges)} edges")

