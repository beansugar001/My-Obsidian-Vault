from pathlib import Path
import tkinter

TCL = Path(__file__).with_name("v141_gpio_ack.tcl")
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
set mock_active 0
set mock_frame 0
set mock_bits {}
set mock_bytes {}
set mock_rises 0
set mock_failed_once 0
set mock_gpio_dir 0
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
        if {![info exists ::mock_mmio(0x4000015C)] || $::mock_case eq "BUS_LOW"} {
            return 0x20
        }
        set pins [expr {0x2C & ~$::mock_gpio_dir}]
        if {$::mock_active && $::mock_rises == 9 && $::mock_gpio_dir == 0} {
            if {$::mock_case eq "ACK_FIRST" && $::mock_frame == 1} {set pins 0x24}
            if {$::mock_case eq "ACK_SECOND" && $::mock_frame == 2} {set pins 0x24}
            if {$::mock_case eq "ACK_SCL_LOW"} {set pins 0x28}
        }
        return $pins
    }
    if {[info exists ::mock_mmio($address)]} {return $::mock_mmio($address)}
    return 0
}

proc mock_write {address value} {
    lappend ::mock_writes [list $address $value]
    if {$address eq "0x40000104"} {
        set previous $::mock_gpio_dir
        if {$::mock_case eq "DIR_FAIL" && $previous == 8 && $value == 12 && !$::mock_failed_once} {
            set ::mock_failed_once 1
            return
        }
        if {!$::mock_active && $previous == 0 && $value == 8} {
            set ::mock_active 1
            incr ::mock_frame
            set ::mock_rises 0
            set ::mock_bits {}
        }
        if {$::mock_active && ($previous & 4) && !($value & 4)} {
            incr ::mock_rises
            if {$::mock_rises <= 8} {
                lappend ::mock_bits [expr {($value & 8) == 0}]
            }
            if {$::mock_rises == 9 && $value != 0} {error "ACK_MASTER_DRIVES_SDA"}
        }
        if {$::mock_active && $previous == 8 && $value == 0} {
            if {$::mock_rises == 10} {
                lappend ::mock_bytes [join $::mock_bits ""]
            }
            set ::mock_active 0
        }
        set ::mock_gpio_dir $value
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


def run_case(case, status, completed_frames, expected_acks=()):
    interp = tkinter.Tcl()
    interp.setvar("mock_case", case)
    interp.eval(MOCK_OPENOCD)
    interp.eval(TCL.read_text(encoding="utf-8"))
    logs = tuple(map(str, interp.splitlist(interp.getvar("mock_log"))))
    frames = [line for line in logs if line.startswith("V141_FRAME_RESULT ")]
    issued = interp.splitlist(interp.getvar("mock_writes"))
    assert len(issued) <= 66, case
    assert f"V141_RESULT={status} HALTS=1 WRITES={len(issued)}" in logs, logs[-6:]
    assert len(frames) == completed_frames, (case, frames)
    assert tuple(line.split(" result=")[1].split()[0] for line in frames) == expected_acks
    assert tuple(map(str, interp.splitlist(interp.getvar("mock_bytes")))) == (
        "01111000", "01111010"
    )[:completed_frames], case
    assert int(interp.getvar("mock_gpio_dir")) == 0, (case, logs[-6:])
    assert int(interp.getvar("mock_shutdowns")) == 1
    assert logs[-1] == "V141_COMPLETE"
    assert all(int(str(interp.splitlist(pair)[0]), 0) in {
        0x4002180C, 0x4000015C, 0x40000158, 0x40000104
    } for pair in issued), case
    if case == "NOT_COLD":
        assert not issued
    if case == "DIR_FAIL":
        assert any(line.startswith("V141_ERROR_RELEASE rc=0 ") for line in logs), case
    print(f"PASS {case}: status={status}, frames={len(frames)}, target_writes={len(issued)}")


if __name__ == "__main__":
    run_case("NACK_BOTH", "BOTH_ADDRESS_NACK", 2, ("NACK", "NACK"))
    run_case("ACK_FIRST", "ADDRESS_ACK_OBSERVED", 2, ("ACK", "NACK"))
    run_case("ACK_SECOND", "ADDRESS_ACK_OBSERVED", 2, ("NACK", "ACK"))
    run_case("BUS_LOW", "FAIL_OR_UNKNOWN", 0)
    run_case("DIR_FAIL", "FAIL_OR_UNKNOWN", 0)
    run_case("ACK_SCL_LOW", "FAIL_OR_UNKNOWN", 0)
    run_case("NOT_COLD", "FAIL_OR_UNKNOWN", 0)
