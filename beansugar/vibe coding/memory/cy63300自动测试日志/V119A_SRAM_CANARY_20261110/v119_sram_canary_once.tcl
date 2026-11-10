set ::v119_status "INCOMPLETE_OR_UNKNOWN"
set ::v119_halt_requests 0
set ::v119_image $::env(V119_IMAGE)
set ::v119_preimage $::env(V119_PREIMAGE)
set ::v119_sram_loaded 0
set ::v119_preimage_saved 0
set ::v119_preimage_restored 0
set ::v119_resume_error 0
set ::v119_magic 0x534D5231
set ::v119_stage 0x119A0010
set ::v119_started 0x42454731
set ::v119_done 0x444F4E45

proc v119_dread {r label} {
    set out [capture [format "riscv dmi_read 0x%X" $r]]
    if {![regexp -nocase {0x([0-9a-f]+)} $out -> x]} { error "DMI_READ_PARSE:$label raw=<$out>" }
    scan $x %x v
    set v [expr {$v & 0xffffffff}]
    echo [format "V119_DMI %s reg=0x%X value=0x%08X" $label $r $v]
    return $v
}
proc v119_csr_read {csr label} {
    riscv dmi_write 0x17 [format "0x%08X" [expr {0x00220000 | $csr}]]
    set ac [v119_dread 0x16 "ABSTRACTCS_$label"]
    if {$ac & 0x00001F00} { error "ABSTRACTCS_BUSY_OR_ERROR:$label value=[format 0x%08X $ac]" }
    return [v119_dread 0x04 "CSR_$label"]
}
proc v119_read_mem {addr words label} {
    set out [capture [format "mdw 0x%08X %d" $addr $words]]
    echo [format "V119_MEM_%s_BEGIN" $label]; echo $out; echo [format "V119_MEM_%s_END" $label]
    return $out
}

set ::v119_rc [catch {
    if {![info exists ::v119_authorized] || $::v119_authorized != 1} { error "V119_AUTH_REQUIRED" }
    if {[file size $::v119_image] != 76} { error "CANARY_IMAGE_LENGTH_MISMATCH" }

    set init [capture {init}]
    echo "V119_INIT_BEGIN"; echo $init; echo "V119_INIT_END"
    if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} { error "JTAG_INIT_FAIL" }
    if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $init]} { error "TAP_IDCODE_FAIL" }
    if {![regexp -nocase {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} { error "DAPLINK_SERIAL_FAIL" }

    set state [riscv.cpu curstate]
    echo "V119_CPU_INITIAL=$state"
    if {$state eq "running"} { echo "V119_HALT_PRE=ONCE"; halt 2000; incr ::v119_halt_requests }
    set state [riscv.cpu curstate]
    echo "V119_CPU_PRE_RUN=$state"
    if {$state ne "halted" || $::v119_halt_requests > 1} { error "CPU_NOT_HALTED" }

    set dm1 [v119_dread 0x11 DMSTATUS_A]
    set dm2 [v119_dread 0x11 DMSTATUS_B]
    set sb [v119_dread 0x38 SBCS]
    if {($dm1 & 0x300) != 0x300 || ($dm1 & 0xC00) != 0 || $dm1 != $dm2} { error "DMSTATUS_UNSTABLE_OR_NOT_HALTED" }
    if {$sb & 0x00607000} { error "SBA_BUSY_OR_ERROR" }
    echo [format "V119_PRE_DMSTATUS=0x%08X SBCS=0x%08X" $dm1 $sb]

    set dpc1 [v119_csr_read 0x7b1 DPC_A]
    set dpc2 [v119_csr_read 0x7b1 DPC_B]
    set dcsr1 [v119_csr_read 0x7b0 DCSR_A]
    set dcsr2 [v119_csr_read 0x7b0 DCSR_B]
    set misa1 [v119_csr_read 0x301 MISA_A]
    set misa2 [v119_csr_read 0x301 MISA_B]
    echo [format "V119_CSR_BASELINE DPC_A=0x%08X DPC_B=0x%08X DCSR_A=0x%08X DCSR_B=0x%08X MISA_A=0x%08X MISA_B=0x%08X" $dpc1 $dpc2 $dcsr1 $dcsr2 $misa1 $misa2]
    if {$dpc1 != $dpc2 || $dcsr1 != $dcsr2 || $misa1 != $misa2} { error "DEBUG_CSR_UNSTABLE" }
    # The observed DPC=0x00000001 is not a valid aligned RV32 instruction PC.
    # Do not write SRAM or request resume until the PC/DPC path is understood.
    if {$dpc1 & 0x3} { error [format "DPC_ALIGNMENT_BLOCK:0x%08X" $dpc1] }

    dump_image $::v119_preimage 0x20008000 76
    set ::v119_preimage_saved 1
    echo "V119_SRAM_PREIMAGE_SAVED bytes=76 address=0x20008000"
    v119_read_mem 0x2000F000 5 MAILBOX_BEFORE

    echo "V119_CANARY_LOAD_BEGIN address=0x20008000 bytes=76"
    # Mark the scratch window as potentially modified before load_image begins,
    # so a partial loader failure still enters the guarded restore path.
    set ::v119_sram_loaded 1
    load_image $::v119_image 0x20008000 bin
    verify_image $::v119_image 0x20008000 bin
    echo "V119_CANARY_VERIFY_PASS"

    echo "V119_RESUME_BEGIN address=0x20008000"
    set resume_rc [catch {set resume_out [capture {resume 0x20008000}]} resume_err]
    if {$resume_rc} {
        set ::v119_resume_error 1
        echo "V119_RESUME_TCL_ERROR=$resume_err"
    } else {
        echo "V119_RESUME_OUTPUT_BEGIN"; echo $resume_out; echo "V119_RESUME_OUTPUT_END"
        if {[regexp -nocase {Error:|Written PC.*does not match|failed|timeout} $resume_out]} { set ::v119_resume_error 1 }
    }
    echo "V119_RESUME_REQUESTS=1"
    if {!$::v119_resume_error} { sleep 50 }

    set state [riscv.cpu curstate]
    echo "V119_CPU_AFTER_RESUME=$state"
    if {$state eq "running"} {
        echo "V119_HALT_POST=ONCE"; halt 2000; incr ::v119_halt_requests
        set state [riscv.cpu curstate]
    }
    echo "V119_CPU_AFTER_POST_HALT=$state"
    if {$state ne "halted" || $::v119_halt_requests > 2} { error "POSTRUN_HALT_FAILED" }

    set dm3 [v119_dread 0x11 DMSTATUS_POST]
    set sb2 [v119_dread 0x38 SBCS_POST]
    if {($dm3 & 0x300) != 0x300 || ($dm3 & 0xC00) != 0 || ($sb2 & 0x00607000)} { error "POSTRUN_DEBUG_STATE_INVALID" }
    set dpc_post [v119_csr_read 0x7b1 DPC_POST]
    set dcsr_post [v119_csr_read 0x7b0 DCSR_POST]
    echo [format "V119_POST_STATE DMSTATUS=0x%08X SBCS=0x%08X DPC=0x%08X DCSR=0x%08X" $dm3 $sb2 $dpc_post $dcsr_post]

    set mb [v119_read_mem 0x2000F000 5 MAILBOX_AFTER]
    set marker_ok [regexp -nocase {0x2000f000\s*:\s*534d5231\s+119a0010\s+42454731\s+444f4e45\s+00000001} $mb]
    echo "V119_UNIQUE_MAILBOX_MATCH=$marker_ok"

    # Restore exactly the 76-byte scratch code window after the hart is halted.
    load_image $::v119_preimage 0x20008000 bin
    verify_image $::v119_preimage 0x20008000 bin
    set ::v119_preimage_restored 1
    echo "V119_SRAM_PREIMAGE_RESTORE_PASS bytes=76"

    if {$marker_ok && !$::v119_resume_error} {
        set ::v119_status "SRAM_CANARY_PASS"
    } elseif {$marker_ok && $::v119_resume_error} {
        set ::v119_status "EXECUTED_BUT_PC_VERIFY_FAULT"
    } else {
        set ::v119_status "EXECUTION_UNPROVEN"
    }
} ::v119_err]

if {$::v119_rc} {
    echo "V119_TCL_ERROR=$::v119_err"
    set ::v119_status "FAIL_OR_UNKNOWN"
    # Restore scratch only when saved, loaded, and the hart is confirmed halted.
    if {$::v119_preimage_saved && $::v119_sram_loaded && [catch {riscv.cpu curstate} st] == 0 && $st eq "halted"} {
        if {[catch {load_image $::v119_preimage 0x20008000 bin; verify_image $::v119_preimage 0x20008000 bin} restore_err] == 0} {
            set ::v119_preimage_restored 1
            echo "V119_SRAM_PREIMAGE_RESTORE_PASS bytes=76 cleanup=1"
        } else {
            echo "V119_SRAM_PREIMAGE_RESTORE_FAIL=$restore_err"
        }
    }
}
echo [format "V119_RESULT=%s RESUME_ERROR=%d HALT_REQUESTS=%d PREIMAGE_SAVED=%d PREIMAGE_RESTORED=%d SRAM_LOADED=%d TARGET_MMIO_WRITES=0 FLASH_NVR_WRITES=0" $::v119_status $::v119_resume_error $::v119_halt_requests $::v119_preimage_saved $::v119_preimage_restored $::v119_sram_loaded]
echo "V119_COMPLETE"
shutdown



