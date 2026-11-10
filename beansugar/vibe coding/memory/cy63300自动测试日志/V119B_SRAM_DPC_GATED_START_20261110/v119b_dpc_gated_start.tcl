# V119B: bounded SRAM canary with independently verified DPC setup.
# This Tcl writes only SRAM 0x20008000..0x2000804B, mailbox SRAM at
# 0x2000F000..0x2000F013 (by the canary CPU), and CSR DPC once.
# No MMIO, Flash/NVR, reset, power-cycle, retry, or automatic DPC restore.
if {![info exists ::v119b_authorized] || $::v119b_authorized != 1} { error "V119B_AUTH_REQUIRED" }
set ::v119b_status "INCOMPLETE_OR_UNKNOWN"
set ::v119b_halt_requests 0
set ::v119b_resume_requests 0
set ::v119b_dpc_write_attempted 0
set ::v119b_sram_loaded 0
set ::v119b_preimage_saved 0
set ::v119b_preimage_restored 0
set ::v119b_mailbox_saved 0
set ::v119b_mailbox_restored 0
set ::v119b_resume_error 0
set ::v119b_image $::env(V119B_IMAGE)
set ::v119b_preimage $::env(V119B_PREIMAGE)
set ::v119b_mailbox_preimage $::env(V119B_MAILBOX_PREIMAGE)
set ::v119b_entry 0x20008000
set ::v119b_magic 0x534D5231
set ::v119b_stage 0x119B0010
set ::v119b_started 0x42454731
set ::v119b_done 0x444F4E45

proc v119b_dread {r label} {
    set out [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> x]} { error "DMI_READ_PARSE:$label raw=<$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V119B_DMI %s reg=0x%X value=0x%08X" $label $r $v]
    return $v
}
proc v119b_idle {label} {
    set ac [v119b_dread 0x16 "ABSTRACTCS_$label"]
    if {($ac & 0x00001F00) != 0 || ($ac & 0x00001000) != 0} { error "ABSTRACTCS_BUSY_OR_ERROR:$label" }
    return $ac
}
proc v119b_csr_read {csr label} {
    v119b_idle "PRE_$label"
    riscv dmi_write 0x17 [format "0x%08X" [expr {0x00220000 | $csr}]]
    set ac [v119b_idle "READ_$label"]
    set value [v119b_dread 0x04 "CSR_$label"]
    echo [format "V119B_CSR_READ %s value=0x%08X abstractcs=0x%08X" $label $value $ac]
    return $value
}
proc v119b_csr_write_once {csr value label} {
    v119b_idle "PREWRITE_$label"
    set ::v119b_dpc_write_attempted 1
    echo [format "V119B_CSR_WRITE_ONCE_BEGIN %s csr=0x%03X value=0x%08X" $label $csr $value]
    riscv dmi_write 0x04 [format "0x%08X" $value]
    riscv dmi_write 0x17 [format "0x%08X" [expr {0x00230000 | $csr}]]
    set ac [v119b_idle "WRITE_$label"]
    echo [format "V119B_CSR_WRITE_ONCE_COMMAND_COMPLETE %s abstractcs=0x%08X" $label $ac]
}
proc v119b_read_mailbox {label} {
    set out [capture {mdw 0x2000F000 5}]
    echo [format "V119B_MAILBOX_%s_BEGIN" $label]
    echo $out
    echo [format "V119B_MAILBOX_%s_END" $label]
    return $out
}
proc v119b_mailbox_match {out} {
    return [regexp -nocase {0x2000f000\s*:\s*534d5231\s+119b0010\s+42454731\s+444f4e45\s+00000001} $out]
}
proc v119b_halt_if_running {label} {
    set st [riscv.cpu curstate]
    echo "V119B_CPU_${label}_BEFORE=$st"
    if {$st eq "running"} {
        if {$::v119b_halt_requests >= 2} { error "HALT_BUDGET_EXHAUSTED:$label" }
        echo "V119B_HALT_${label}=ONCE"
        halt 2000
        incr ::v119b_halt_requests
        set st [riscv.cpu curstate]
    }
    echo "V119B_CPU_${label}_AFTER=$st"
    if {$st ne "halted"} { error "CPU_NOT_CONFIRMED_HALTED:$label" }
    return $st
}

set ::v119b_rc [catch {
    if {[file size $::v119b_image] != 76} { error "CANARY_IMAGE_LENGTH_MISMATCH" }
    set init [capture {init}]
    echo "V119B_INIT_BEGIN"; echo $init; echo "V119B_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_FAIL" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_FAIL" }
    if {![regexp -nocase {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "DAPLINK_SERIAL_FAIL" }

    set state [riscv.cpu curstate]
    echo "V119B_CPU_INITIAL=$state"
    if {$state eq "running"} { halt 2000; incr ::v119b_halt_requests }
    if {[riscv.cpu curstate] ne "halted" || $::v119b_halt_requests > 1} { error "CPU_NOT_HALTED_PRELOAD" }
    set dm1 [v119b_dread 0x11 DMSTATUS_A]
    set dm2 [v119b_dread 0x11 DMSTATUS_B]
    set sb [v119b_dread 0x38 SBCS]
    if {($dm1 & 0x300) != 0x300 || ($dm1 & 0xC00) != 0 || $dm1 != $dm2} { error "DMSTATUS_UNSTABLE_OR_NOT_HALTED" }
    if {$sb & 0x00607000} { error "SBA_BUSY_OR_ERROR" }
    v119b_idle PREFLIGHT
    set dpc0 [v119b_csr_read 0x7B1 DPC_BEFORE]
    set dcsr0 [v119b_csr_read 0x7B0 DCSR_BEFORE]
    set misa0 [v119b_csr_read 0x301 MISA_BEFORE]
    echo [format "V119B_BASELINE DMSTATUS=0x%08X SBCS=0x%08X DPC=0x%08X DCSR=0x%08X MISA=0x%08X" $dm1 $sb $dpc0 $dcsr0 $misa0]

    dump_image $::v119b_preimage $::v119b_entry 76
    set ::v119b_preimage_saved 1
    echo "V119B_PREIMAGE_SAVED bytes=76 address=0x20008000"
    dump_image $::v119b_mailbox_preimage 0x2000F000 20
    set ::v119b_mailbox_saved 1
    echo "V119B_MAILBOX_PREIMAGE_SAVED bytes=20 address=0x2000F000"
    v119b_read_mailbox BEFORE
    set ::v119b_sram_loaded 1
    echo "V119B_CANARY_LOAD_BEGIN address=0x20008000 bytes=76"
    load_image $::v119b_image $::v119b_entry bin
    verify_image $::v119b_image $::v119b_entry bin
    echo "V119B_CANARY_VERIFY_PASS"

    # Set DPC using the same abstract CSR write order as OpenOCD: DATA0, then COMMAND.
    # Do not use `resume <address>`: this build's generic resume path ignores a failed
    # DPC write-back result before issuing RESUMEREQ.
    v119b_csr_write_once 0x7B1 $::v119b_entry DPC_ENTRY
    # Read promptly, then inspect hart state. A DPC write has previously caused
    # this target to leave halted state, so a changed DPC while running may mean
    # the canary is already advancing; never issue a second start in that branch.
    set dpc_rc [catch {set dpc1 [v119b_csr_read 0x7B1 DPC_AFTER_WRITE]} dpc_err]
    echo [format "V119B_DPC_READBACK rc=%d expected=0x%08X actual=%s detail=%s" $dpc_rc $::v119b_entry [expr {$dpc_rc ? "UNKNOWN" : [format 0x%08X $dpc1]}] $dpc_err]
    set state [riscv.cpu curstate]
    echo "V119B_CPU_AFTER_DPC_WRITE=$state"
    if {$state eq "running"} {
        echo "V119B_DPC_WRITE_STARTED_HART=1"
        sleep 50
        v119b_halt_if_running POST_DPC
    } elseif {$state eq "halted"} {
        if {$dpc_rc || $dpc1 != $::v119b_entry} { error "DPC_ENTRY_READBACK_MISMATCH_NO_RESUME" }
        # Address is already independently written/read back. A no-argument resume
        # uses the current DPC and skips another PC/DPC write in OpenOCD's code path.
        set ::v119b_resume_requests 1
        echo "V119B_RESUME_CURRENT_ONCE"
        resume
        sleep 50
        v119b_halt_if_running POST_RESUME
    } else {
        error "CPU_STATE_UNKNOWN_AFTER_DPC_WRITE:$state"
    }

    set dm3 [v119b_dread 0x11 DMSTATUS_POST]
    set sb2 [v119b_dread 0x38 SBCS_POST]
    if {($dm3 & 0x300) != 0x300 || ($dm3 & 0xC00) != 0 || ($sb2 & 0x00607000)} { error "POSTRUN_DEBUG_STATE_INVALID" }
    set dpc2 [v119b_csr_read 0x7B1 DPC_POST]
    set mailbox [v119b_read_mailbox AFTER]
    set match [v119b_mailbox_match $mailbox]
    echo [format "V119B_POST DMSTATUS=0x%08X SBCS=0x%08X DPC=0x%08X MAILBOX_MATCH=%d" $dm3 $sb2 $dpc2 $match]

    # Restore only the overwritten code window. Leave DPC at the canary entry;
    # another DPC write can change hart state on this target.
    load_image $::v119b_preimage $::v119b_entry bin
    verify_image $::v119b_preimage $::v119b_entry bin
    set ::v119b_preimage_restored 1
    echo "V119B_PREIMAGE_RESTORE_PASS bytes=76"
    load_image $::v119b_mailbox_preimage 0x2000F000 bin
    verify_image $::v119b_mailbox_preimage 0x2000F000 bin
    set ::v119b_mailbox_restored 1
    echo "V119B_MAILBOX_PREIMAGE_RESTORE_PASS bytes=20"
    if {$match} { set ::v119b_status "SRAM_CANARY_PASS" } else { set ::v119b_status "SRAM_EXECUTION_UNPROVEN" }
} ::v119b_err]

if {$::v119b_rc} {
    echo "V119B_TCL_ERROR=$::v119b_err"
    set ::v119b_status "FAIL_OR_UNKNOWN"
    # Never resume during cleanup. If execution might be active, request a single
    # halt only if the one post-start halt slot remains; restore code only if halted.
    set state_rc [catch {riscv.cpu curstate} state]
    if {$state_rc == 0 && $state eq "running" && $::v119b_halt_requests < 2} {
        catch {echo "V119B_FAILSAFE_HALT_ONCE"; halt 2000; incr ::v119b_halt_requests}
        set state_rc [catch {riscv.cpu curstate} state]
    }
    if {$state_rc != 0} { set state "UNKNOWN" }
    if {$::v119b_preimage_saved && $::v119b_sram_loaded && $state_rc == 0 && $state eq "halted"} {
        if {[catch {load_image $::v119b_preimage $::v119b_entry bin; verify_image $::v119b_preimage $::v119b_entry bin} restore_err] == 0} {
            set ::v119b_preimage_restored 1
            echo "V119B_PREIMAGE_RESTORE_PASS bytes=76 cleanup=1"
        } else {
            echo "V119B_PREIMAGE_RESTORE_FAIL=$restore_err"
        }
    } else {
        echo "V119B_PREIMAGE_RESTORE_SKIPPED state_rc=$state_rc state=$state"
    }
    if {$::v119b_mailbox_saved && $state_rc == 0 && $state eq "halted"} {
        if {[catch {load_image $::v119b_mailbox_preimage 0x2000F000 bin; verify_image $::v119b_mailbox_preimage 0x2000F000 bin} restore_err] == 0} {
            set ::v119b_mailbox_restored 1
            echo "V119B_MAILBOX_PREIMAGE_RESTORE_PASS bytes=20 cleanup=1"
        } else {
            echo "V119B_MAILBOX_PREIMAGE_RESTORE_FAIL=$restore_err"
        }
    }
}
echo [format "V119B_RESULT=%s DPC_WRITE_ATTEMPTED=%d RESUME_REQUESTS=%d HALT_REQUESTS=%d PREIMAGE_SAVED=%d PREIMAGE_RESTORED=%d MAILBOX_SAVED=%d MAILBOX_RESTORED=%d SRAM_LOADED=%d TARGET_MMIO_WRITES=0 FLASH_NVR_WRITES=0" $::v119b_status $::v119b_dpc_write_attempted $::v119b_resume_requests $::v119b_halt_requests $::v119b_preimage_saved $::v119b_preimage_restored $::v119b_mailbox_saved $::v119b_mailbox_restored $::v119b_sram_loaded]
echo "V119B_COMPLETE"
shutdown
