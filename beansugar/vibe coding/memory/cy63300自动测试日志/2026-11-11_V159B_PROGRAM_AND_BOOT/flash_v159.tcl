proc read_word {addr} {
    set out [capture [format "mdw 0x%08X" $addr]]
    if {![regexp -nocase {0x[0-9a-f]+:\s+([0-9a-f]+)} $out -> value]} {error "MDW_FAILED:$out"}
    scan $value %x result
    return [expr {$result & 0xffffffff}]
}
proc read_dmi {reg} {
    set out [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> value]} {error "DMI_FAILED:$out"}
    scan $value %x result
    return [expr {$result & 0xffffffff}]
}
proc write_word {addr value} {
    set phase $::env(V159B_PHASE)
    set fixed {
        {0x40022000 0} {0x40022004 1} {0x40022008 0x00100150}
    }
    if {$phase eq "erase"} {
        lappend fixed {0x40022018 0x00007DFF} {0x40022020 0x0CA00340} {0x40022000 2}
        lappend fixed [list $::env(V159B_TRIGGER) 0xffffffff]
    } elseif {$phase eq "program"} {
        lappend fixed {0x4002200C 0x00820480} {0x40022010 0x00100010}
        lappend fixed {0x40022014 0x00000340} {0x40022000 1}
    } else {error "WRITE_PHASE_DENIED"}
    set ok 0
    foreach pair $fixed {
        if {$addr == [lindex $pair 0] && $value == [lindex $pair 1]} {set ok 1}
    }
    if {$addr == 0x4002180C && $value == $::flash_clk} {set ok 1}
    if {!$ok} {error "WRITE_DENIED"}
    set cmd [format "mww 0x%08X 0x%08X" $addr $value]
    echo "V159B_WRITE $cmd"
    set out [capture $cmd]
    if {$out ne ""} {echo $out}
    if {[regexp -nocase {error:|failed|timeout} $out]} {error "WRITE_FAILED"}
}
proc mode {value} {
    set out [read_word 0x40022000]
    echo [format "V159B_FLS_CR=0x%08X" $out]
    if {$out != $value} {error "UNEXPECTED_FLASH_MODE"}
}
proc preflight {} {
    set out [capture {init}]
    echo $out
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0} $out]} {error "INIT_FAILED"}
    if {[jtag names] ne "riscv.cpu" ||
        ![regexp -nocase {riscv.cpu tap/device found: 0x1e200a6f} $out] ||
        ![regexp {Serial# = 07000001006700343500000a4e57354aa5a5a5a597969908} $out]} {
        error "WRONG_TARGET_OR_PROBE"
    }
    if {$::env(V159B_PHASE) eq "mailbox"} {
        echo "V159B_CPU=[riscv.cpu curstate]"
        return
    }
    if {[riscv.cpu curstate] eq "running"} {echo "V159B_HALT"; halt 2000}
    set dm [read_dmi 0x11]
    set sb [read_dmi 0x38]
    echo [format "V159B_DMSTATUS=0x%08X SBCS=0x%08X" $dm $sb]
    if {[riscv.cpu curstate] ne "halted" || ($dm & 0xF00) != 0x300 || ($sb & 0x00607000)} {
        error "TARGET_NOT_READY"
    }
    if {[read_word 0x40021810] != 0} {error "PERIPHERAL_RESET_ACTIVE"}
    mode 0
}
proc compare_image {path} {
    set out [capture [list verify_image $path 0x00000000 bin]]
    echo $out
    if {[regexp -nocase {error:|fail|diff|mismatch|timeout} $out]} {error "VERIFY_IMAGE_FAILED"}
}
proc action {} {
    preflight
    set phase $::env(V159B_PHASE)
    if {$phase eq "mailbox"} {
        dump_image $::env(V159B_DUMP) 0x2000F000 56
        return
    }
    if {$phase eq "snapshot"} {
        dump_image $::env(V159B_DUMP) 0x00000000 0x00010000
        return
    }
    if {$phase eq "erase"} {
        set trigger $::env(V159B_TRIGGER)
        if {$trigger != 0 && $trigger != 0x200 && $trigger != 0x400} {error "ERASE_RANGE_DENIED"}
    } elseif {$phase ne "program"} {error "UNKNOWN_PHASE"}
    compare_image $::env(V159B_EXPECTED)
    set clk [read_word 0x4002180C]
    set ::flash_clk [expr {$clk | 0x00080000}]
    if {$clk != $::flash_clk} {
        write_word 0x4002180C $::flash_clk
        if {[read_word 0x4002180C] != $::flash_clk} {error "FLASH_CLOCK_NOT_ENABLED"}
    }
    write_word 0x40022004 1
    write_word 0x40022008 0x00100150
    if {$phase eq "erase"} {
        write_word 0x40022018 0x00007DFF
        write_word 0x40022020 0x0CA00340
        set ::armed 1
        write_word 0x40022000 2
        mode 2
        echo [format "V159B_ERASE_TRIGGER=0x%08X" $trigger]
        write_word $trigger 0xffffffff
        sleep 100
    } else {
        write_word 0x4002200C 0x00820480
        write_word 0x40022010 0x00100010
        write_word 0x40022014 0x00000340
        set ::armed 1
        write_word 0x40022000 1
        mode 1
        echo "V159B_PROGRAM_BEGIN address=0x0 bytes=2120"
        load_image $::env(V159B_IMAGE) 0x00000000 bin
        compare_image $::env(V159B_IMAGE)
    }
    write_word 0x40022000 0
    mode 0
    set ::armed 0
    dump_image $::env(V159B_DUMP) 0x00000000 0x00010000
}

set ::armed 0
set rc [catch {action} detail]
if {$rc} {
    echo "V159B_ERROR=$detail"
    if {$::armed} {
        set recovery [catch {write_word 0x40022000 0; mode 0} message]
        echo "V159B_MODE_EXIT_RC=$recovery detail=$message"
    }
}
echo "V159B_COMPLETE phase=$::env(V159B_PHASE) rc=$rc"
shutdown
