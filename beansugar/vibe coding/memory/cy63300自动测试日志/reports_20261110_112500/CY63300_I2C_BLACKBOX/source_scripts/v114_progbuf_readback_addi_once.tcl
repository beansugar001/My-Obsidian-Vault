# V114: verify DMI Program Buffer write/readback before a harmless GPR-only addi.
# No SBA access, target memory/MMIO, reset, resume, Flash/NVR or power operation.
if {![info exists ::v114_progbuf_authorized] || $::v114_progbuf_authorized != 1} {
    error "V114_AUTH_REQUIRED"
}
set ::v114_status "INCOMPLETE_OR_UNKNOWN"
set ::v114_postexec_count 0
set ::v114_halt_count 0
set ::v114_restore "NOT_STARTED"
set ::v114_error ""
set ::v114_probe_serial "07000001006700343500000a4e57354aa5a5a5a597969908"
set ::v114_x7_saved 0
set ::v114_dpc_saved 0
set ::v114_x7_before 0
set ::v114_dpc_before 0
set ::v114_base 0x12345800
set ::v114_instruction 0x00138393 ;# addi x7,x7,1

proc v114_read {reg} {
    set raw [capture [format "riscv dmi_read 0x%X" $reg]]
    if {![regexp -nocase {0x([0-9a-f]+)} $raw -> hex]} {
        error "V114_DMI_READ_PARSE_FAIL reg=[format 0x%X $reg] raw=<$raw>"
    }
    scan $hex %x value
    return [expr {$value & 0xffffffff}]
}
proc v114_write {reg value label} {
    echo [format "V114_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]
    riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]]
}
proc v114_abstract_idle {label} {
    set a [v114_read 0x16]
    echo [format "V114_ABSTRACTCS label=%s value=0x%08X" $label $a]
    if {(($a >> 8) & 7) != 0 || ($a & 0x1000) != 0} {
        error "V114_ABSTRACTCS_BUSY_OR_ERROR:$label"
    }
    if {(($a >> 24) & 31) != 1 || ($a & 0xF) != 3} {
        error "V114_ABSTRACTCS_CAPABILITY_MISMATCH:$label"
    }
}
proc v114_gpr_read {n} {
    v114_write 0x17 [expr {0x00221000 | $n}] "READ_X$n"
    v114_abstract_idle "READ_X$n"
    return [v114_read 0x04]
}
proc v114_gpr_write {n value} {
    v114_write 0x04 $value "WRITE_X${n}_DATA"
    v114_write 0x17 [expr {0x00231000 | $n}] "WRITE_X$n"
    v114_abstract_idle "WRITE_X$n"
}
proc v114_csr_read {csr label} {
    v114_write 0x17 [expr {0x00220000 | $csr}] "${label}_CMD"
    v114_abstract_idle $label
    return [v114_read 0x04]
}
proc v114_csr_write {csr value label} {
    v114_write 0x04 $value "${label}_DATA"
    v114_write 0x17 [expr {0x00230000 | $csr}] $label
    v114_abstract_idle $label
}

set ::v114_phase_rc [catch {
    set initlog [capture {init}]
    echo "V114_INIT_BEGIN"; echo $initlog; echo "V114_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $initlog]} {
        error "V114_JTAG_INIT_ERROR"
    }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $initlog]} {
        error "V114_TAP_OR_IDCODE_MISMATCH"
    }
    if {![regexp $::v114_probe_serial $initlog]} { error "V114_PROBE_SERIAL_MISMATCH" }
    set state [riscv.cpu curstate]
    echo "V114_CPU_INITIAL=$state"
    if {$state eq "running"} {
        set haltlog [capture {halt 2000}]
        incr ::v114_halt_count
        echo "V114_HALT=$haltlog"
    }
    if {[riscv.cpu curstate] ne "halted" || $::v114_halt_count > 1} {
        error "V114_CPU_NOT_HALTED"
    }
    set dm [v114_read 0x11]
    set abstractcs [v114_read 0x16]
    set abstractauto [v114_read 0x18]
    echo [format "V114_PREFLIGHT DMSTATUS=0x%08X ABSTRACTCS=0x%08X ABSTRACTAUTO=0x%08X" $dm $abstractcs $abstractauto]
    if {($dm & 0x300) != 0x300 || ($dm & 0xC00) != 0} { error "V114_HART_NOT_HALTED" }
    if {(($abstractcs >> 24) & 31) != 1 || ($abstractcs & 0xF) != 3 || (($abstractcs >> 8) & 7) != 0 || ($abstractcs & 0x1000) != 0 || $abstractauto != 0} {
        error "V114_ABSTRACT_DEBUG_NOT_IDLE_OR_UNSUPPORTED"
    }

    set prog_before [v114_read 0x20]
    echo [format "V114_PROGBUF0_BEFORE=0x%08X" $prog_before]
    set ::v114_x7_before [v114_gpr_read 7]
    set ::v114_dpc_before [v114_csr_read 0x7B1 DPC_READ]
    set ::v114_x7_saved 1
    set ::v114_dpc_saved 1
    echo [format "V114_SAVED x7=0x%08X DPC=0x%08X" $::v114_x7_before $::v114_dpc_before]

    v114_gpr_write 7 $::v114_base
    set base_rb [v114_gpr_read 7]
    echo [format "V114_X7_BASE_READBACK=0x%08X" $base_rb]
    if {$base_rb != $::v114_base} { error "V114_X7_SETUP_NOT_CONFIRMED" }

    v114_write 0x20 $::v114_instruction PROGBUF0_ADDI
    set prog_after [v114_read 0x20]
    echo [format "V114_PROGBUF0_AFTER_WRITE=0x%08X" $prog_after]
    if {$prog_after != $::v114_instruction} {
        set ::v114_status "PROGBUF_WRITE_READBACK_MISMATCH_NO_EXEC"
        error "V114_PROGBUF_NOT_VERIFIED_STOP_BEFORE_EXEC"
    }

    v114_abstract_idle PRE_POSTEXEC
    incr ::v114_postexec_count
    v114_write 0x17 0x00240000 POSTEXEC_ADDI_ONCE
    v114_abstract_idle POSTEXEC_ADDI
    set dm_after [v114_read 0x11]
    if {($dm_after & 0x200) == 0 || ($dm_after & 0xC00) != 0} { error "V114_HART_NOT_HALTED_AFTER_POSTEXEC" }
    set x7_after [v114_gpr_read 7]
    echo [format "V114_X7_AFTER_POSTEXEC=0x%08X" $x7_after]
    if {$x7_after == ($::v114_base + 1)} {
        set ::v114_status "POSTEXEC_ADDI_PASS"
    } else {
        set ::v114_status "POSTEXEC_NO_VISIBLE_GPR_CHANGE"
    }
} ::v114_error]
if {$::v114_phase_rc} {
    echo "V114_PHASE_ERROR=$::v114_error"
    if {$::v114_status eq "INCOMPLETE_OR_UNKNOWN"} { set ::v114_status "FAIL_OR_UNKNOWN" }
}

# Restore GPR/PC state and leave an inert NOP in the single-slot Program Buffer.
if {$::v114_x7_saved} {
    set rr [catch {v114_gpr_write 7 $::v114_x7_before; set rb [v114_gpr_read 7]; if {$rb != $::v114_x7_before} {error "X7_RESTORE_READBACK_MISMATCH"}} re]
    echo [format "V114_RESTORE_X7 rc=%d detail=%s" $rr $re]
}
if {$::v114_dpc_saved} {
    set rr [catch {v114_csr_write 0x7B1 $::v114_dpc_before DPC_RESTORE; set rb [v114_csr_read 0x7B1 DPC_FINAL]; if {$rb != $::v114_dpc_before} {error "DPC_RESTORE_READBACK_MISMATCH"}} re]
    echo [format "V114_RESTORE_DPC rc=%d detail=%s" $rr $re]
}
set noprc [catch {v114_write 0x20 0x00000013 FINAL_SAFE_NOP} noperr]
echo [format "V114_FINAL_SAFE_NOP rc=%d detail=%s" $noprc $noperr]
set finaldmrc [catch {set finaldm [v114_read 0x11]} finaldmerr]
echo [format "V114_FINAL_DMSTATUS rc=%d value=%s" $finaldmrc $finaldmerr]
echo [format "V114_RESULT=%s POSTEXEC_COUNT=%d HALT_COUNT=%d" $::v114_status $::v114_postexec_count $::v114_halt_count]
echo "V114_COMPLETE"
shutdown

