from pathlib import Path
import tkinter


TCL = Path(__file__).with_name("v139_cold_start.tcl")
MOCK_OPENOCD = r"""
set mock_log {}
set mock_writes {}
set mock_shutdowns 0
set mock_cpu running
set mock_mode 0x20040404
set mock_addr 0
set mock_data 0
set mock_busy 0
set mock_error 0
set mock_pre_stop 0
set mock_post_stop 0
array set mock_mmio {
    0x40002800 2 0x4000280C 5 0x4000283C 0 0x40002858 0
}
if {$mock_case eq "NOT_COLD"} {set mock_mmio(0x4002180C) 0x21}

proc echo {line} {lappend ::mock_log $line}
proc sleep {ms} {}
proc shutdown {} {incr ::mock_shutdowns}
proc halt {timeout} {
    if {$::mock_case ne "HALT_FAIL"} {set ::mock_cpu halted}
}
proc riscv.cpu {op} {return $::mock_cpu}
proc jtag {op} {return riscv.cpu}
proc init {} {
    return "Info : CMSIS-DAP: Serial# = 07000001006700343500000a4e57354aa5a5a5a597969908\nInfo : JTAG tap: riscv.cpu tap/device found: 0x1e200a6f"
}
proc capture {command} {uplevel 1 $command}

proc mock_read {address} {
    if {$address eq "0x40000150"} {
        if {[info exists ::mock_mmio(0x4000015C)] && $::mock_case ne "PULL_LOW"} {return 0x2C}
        return 0x20
    }
    if {[info exists ::mock_mmio($address)]} {return $::mock_mmio($address)}
    return 0
}

proc mock_write {address value} {
    lappend ::mock_writes [list $address $value]
    if {$address eq "0x40000164" && $::mock_case eq "DRIVE_MISMATCH"} {return}
    if {$address eq "0x40002808"} {
        if {$::mock_case eq "LOST_FIFO_WRITE"} {return}
        set ::mock_mmio(0x4000283C) 1
        set ::mock_mmio(0x4000280C) 0x104
        switch -- $::mock_case {
            DRAIN {
                set ::mock_mmio(0x4000283C) 3
                set ::mock_mmio(0x4000280C) 5
            }
            NACK {set ::mock_mmio(0x40002858) 0x2000}
            SBA_ERROR {set ::mock_error 0x2000}
            FAST_STOP {
                set ::mock_mmio(0x4000283C) 0
                set ::mock_mmio(0x4000280C) 5
                set ::mock_mmio(0x40002858) 0x1000
            }
        }
        return
    }
    if {$address eq "0x40002800"} {set value [expr {$value | 2}]}
    if {$address eq "0x40002828" && $value == 2} {
        set ::mock_mmio(0x4000283C) 0
        set ::mock_mmio(0x40002858) 0x1000
    }
    set ::mock_mmio($address) $value
}

proc riscv {op reg args} {
    switch -- $op {
        dmi_read {
            switch -- $reg {
                0x11 {return 0x00430382}
                0x38 {
                    if {$::mock_busy} {
                        set ::mock_busy 0
                        return [format 0x%X [expr {$::mock_mode | 0x200000}]]
                    }
                    return [format 0x%X [expr {$::mock_mode | $::mock_error}]]
                }
                0x3C {
                    if {$::mock_busy} {error "READ_BEFORE_IDLE"}
                    return [format 0x%X $::mock_data]
                }
            }
        }
        dmi_write {
            if {$::mock_busy} {error "DMI_WRITE_WHILE_BUSY"}
            set value [lindex $args 0]
            switch -- $reg {
                0x38 {set ::mock_mode $value}
                0x39 {
                    set ::mock_addr $value
                    if {$::mock_mode & 0x100000} {
                        set ::mock_data [mock_read $value]
                        set ::mock_busy 1
                    }
                }
                0x3C {
                    mock_write $::mock_addr $value
                    set ::mock_busy 1
                }
            }
        }
        default {error "Unexpected riscv command $op"}
    }
}
"""


CASES = {
    "NOT_COLD": ("FAIL_OR_UNKNOWN", 0, "MISMATCH:CLKEN_COLD_0"),
    "HALT_FAIL": ("FAIL_OR_UNKNOWN", 0, "CPU_NOT_HALTED"),
    "PULL_LOW": ("FAIL_OR_UNKNOWN", 2, "GPIO_INPUT_NOT_HIGH"),
    "DRIVE_MISMATCH": ("FAIL_OR_UNKNOWN", 5, "MISMATCH:GPIOB_HIGH_DRIVE_VERIFY"),
    "STALL": ("TX_STALLED_FIFO_1_WORK_1", 17, None),
    "LOST_FIFO_WRITE": ("TX_PROGRESS_UNKNOWN", 17, None),
    "NACK": ("FAIL_OR_UNKNOWN", 17, "TX_RAW_EVENT:0x00002000"),
    "SBA_ERROR": ("FAIL_OR_UNKNOWN", 17, "SBA_ERROR:ONE_CONTROL_BYTE_WRITE_DONE"),
    "DRAIN": ("TX_DRAINED_STOP_IDLE", 18, None),
    "FAST_STOP": ("TX_EMPTY_AND_IDLE", 17, None),
}


def run_case(name, status, writes, error):
    interp = tkinter.Tcl()
    interp.setvar("mock_case", name)
    interp.eval(MOCK_OPENOCD)
    interp.eval(TCL.read_text(encoding="utf-8"))
    logs = tuple(map(str, interp.splitlist(interp.getvar("mock_log"))))
    issued = interp.splitlist(interp.getvar("mock_writes"))
    expected = interp.splitlist(interp.getvar("v139_allowed"))
    assert int(interp.getvar("mock_shutdowns")) == 1, name
    assert f"V139_RESULT={status} HALTS=1 WRITES={writes}" in logs, logs[-5:]
    assert len(issued) == writes, (name, issued)
    actual_pairs = [tuple(int(str(word), 0) for word in interp.splitlist(pair)) for pair in issued]
    expected_pairs = [tuple(int(str(word), 0) for word in interp.splitlist(pair)) for pair in expected]
    assert actual_pairs == expected_pairs[:writes], (name, actual_pairs)
    assert sum(addr == 0x40002808 for addr, _ in actual_pairs) == (writes >= 17), name
    assert sum(pair == (0x40002828, 2) for pair in actual_pairs) == (name == "DRAIN"), name
    if error:
        assert any(line.startswith(f"V139_ERROR={error}") for line in logs), (name, logs[-5:])
    assert logs[-1] == "V139_COMPLETE", name
    print(f"PASS {name}: status={status} target_writes={writes}")


if __name__ == "__main__":
    for case, expected in CASES.items():
        run_case(case, *expected)
