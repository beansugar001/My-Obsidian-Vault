proc v160b_dmi_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "DMI_READ_PARSE reg=$reg raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}

proc v160b_dmi_write {reg value} {
    if {$reg != 0x38 && $reg != 0x39 && $reg != 0x3C} {
        error "DMI_REGISTER_DENIED"
    }
    echo [format "V160B_DMI_WRITE reg=0x%02X value=0x%08X" $reg $value]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" $value]
}

proc v160b_sba_idle {label attempts} {
    for {set i 0} {$i < $attempts} {incr i} {
        set sbcs [v160b_dmi_read 0x38]
        echo [format "V160B_SBCS %s i=%d sbcs=0x%08X" $label $i $sbcs]
        if {$sbcs & 0x00407000} {error "SBA_ERROR:$label"}
        if {($sbcs & 0x00200000) == 0} {return}
        if {$i + 1 < $attempts} {sleep 1}
    }
    error "SBA_BUSY_TIMEOUT:$label"
}

proc v160b_read {addr label} {
    v160b_sba_idle ${label}_PRE 1
    v160b_dmi_write 0x38 0x20140404
    v160b_sba_idle ${label}_READ_MODE 1
    v160b_dmi_write 0x39 $addr
    v160b_sba_idle ${label}_READ_DONE 50
    set value [v160b_dmi_read 0x3C]
    v160b_sba_idle ${label}_DATA_READ 1
    v160b_dmi_write 0x38 0x20040404
    echo [format "V160B_READ %s addr=0x%08X value=0x%08X" $label $addr $value]
    return $value
}

proc v160b_halted {} {
    if {[riscv.cpu curstate] ne "halted"} {error "CPU_NOT_HALTED"}
    set dm [v160b_dmi_read 0x11]
    echo [format "V160B_DMSTATUS=0x%08X" $dm]
    if {($dm & 0x3F80) != 0x0380} {error "DMSTATUS_NOT_HALTED"}
}


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
    set phase $::env(V160B_PHASE)
    set fixed {
        {0x40022000 0} {0x40022004 1} {0x40022008 0x00100150}
    }
    if {$phase eq "erase"} {
        lappend fixed {0x40022018 0x00007DFF} {0x40022020 0x0CA00340} {0x40022000 2}
        lappend fixed [list $::env(V160B_TRIGGER) 0xffffffff]
    } elseif {$phase eq "program"} {
        lappend fixed {0x4002200C 0x00820480} {0x40022010 0x00100010}
        lappend fixed {0x40022014 0x00000340} {0x40022000 1}
    } else {error "WRITE_PHASE_DENIED"}
    set ok 0
    foreach pair $fixed {
        if {$addr == [lindex $pair 0] && $value == [lindex $pair 1]} {set ok 1}
    }
    if {!$ok} {error "WRITE_DENIED"}
    if {[read_word 0x40021810] != 0} {error "RESET_ACTIVE_BEFORE_WRITE"}
    set cmd [format "mww 0x%08X 0x%08X" $addr $value]
    echo "V160B_WRITE $cmd"
    set out [capture $cmd]
    if {$out ne ""} {echo $out}
    if {[regexp -nocase {error:|failed|timeout} $out]} {error "WRITE_FAILED"}
}
proc mode {value} {
    set out [read_word 0x40022000]
    echo [format "V160B_FLS_CR=0x%08X" $out]
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
    if {$::env(V160B_PHASE) eq "mailbox"} {
        echo "V160B_CPU=[riscv.cpu curstate]"
        return
    }
    if {[riscv.cpu curstate] eq "running"} {echo "V160B_HALT"; halt 2000}
    set dm [read_dmi 0x11]
    set sb [read_dmi 0x38]
    echo [format "V160B_DMSTATUS=0x%08X SBCS=0x%08X" $dm $sb]
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
    set phase $::env(V160B_PHASE)
    if {$phase eq "mailbox"} {
        dump_image $::env(V160B_DUMP) 0x2000F000 68
        return
    }
    if {$phase eq "snapshot"} {
        dump_image $::env(V160B_DUMP) 0x00000000 0x00010000
        return
    }
    if {$phase eq "erase"} {
        set trigger $::env(V160B_TRIGGER)
        if {$trigger != 0} {error "ERASE_RANGE_DENIED"}
    } elseif {$phase ne "program"} {error "UNKNOWN_PHASE"}
    set sentinel_addr $::env(V160B_SENTINEL_ADDR)
    set sentinel_word $::env(V160B_SENTINEL_WORD)
    if {$phase eq "erase" && ($sentinel_addr < $trigger || $sentinel_addr >= $trigger + 0x200)} {
        error "ERASE_SENTINEL_DENIED"
    }
    if {[read_word $sentinel_addr] != $sentinel_word} {error "LIVE_FLASH_SENTINEL_MISMATCH"}
    set clk [read_word 0x4002180C]
    set ::flash_clk [expr {$clk | 0x00080000}]
    if {$clk != $::flash_clk} {
        v160b_halted
        if {[v160b_read 0x40021810 PARK_BEFORE_CLKEN] != 0} {error "RESET_ACTIVE"}
        v160b_sba_idle CLKEN_PRE 1
        v160b_dmi_write 0x38 0x20040404
        v160b_dmi_write 0x39 0x4002180C
        v160b_sba_idle CLKEN_ADDRESS 1
        echo [format "V160B_WRITE SBA 0x4002180C 0x%08X" $::flash_clk]
        v160b_dmi_write 0x3C $::flash_clk
        v160b_sba_idle CLKEN_WRITE_DONE 50
        if {[v160b_read 0x40021810 PARK_AFTER_CLKEN] != 0} {error "RESET_ACTIVE"}
        if {[v160b_read 0x4002180C CLKEN_VERIFY] != $::flash_clk} {error "FLASH_CLOCK_NOT_ENABLED"}
    }
    write_word 0x40022004 1
    write_word 0x40022008 0x00100150
    if {$phase eq "erase"} {
        write_word 0x40022018 0x00007DFF
        write_word 0x40022020 0x0CA00340
        set ::armed 1
        write_word 0x40022000 2
        mode 2
        echo [format "V160B_ERASE_TRIGGER=0x%08X" $trigger]
        write_word $trigger 0xffffffff
        sleep 100
    } else {
        write_word 0x4002200C 0x00820480
        write_word 0x40022010 0x00100010
        write_word 0x40022014 0x00000340
        set ::armed 1
        write_word 0x40022000 1
        mode 1
        echo "V160B_PROGRAM_BEGIN address=0x0 bytes=240"
        load_image $::env(V160B_IMAGE) 0x00000000 bin
        compare_image $::env(V160B_IMAGE)
    }
    write_word 0x40022000 0
    mode 0
    set ::armed 0
    if {$phase eq "erase"} {
        dump_image $::env(V160B_DUMP) 0x00000000 0x00000200
    } else {
        dump_image $::env(V160B_DUMP) 0x00000000 0x000000F0
    }
}

set ::armed 0
set rc [catch {action} detail]
if {$rc} {
    echo "V160B_ERROR=$detail"
    if {$::armed} {
        set recovery [catch {write_word 0x40022000 0; mode 0} message]
        echo "V160B_MODE_EXIT_RC=$recovery detail=$message"
    }
}
echo "V160B_COMPLETE phase=$::env(V160B_PHASE) rc=$rc"
shutdown
