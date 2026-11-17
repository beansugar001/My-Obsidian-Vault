set ::v142_halted_target 0
set ::v142_ram_entered 0

proc v142_test {} {
    init
    if {[target current] ne "stm32f1x.cpu"} {error "UNEXPECTED_TARGET"}
    set cpuid [lindex [read_memory 0xE000ED00 32 1] 0]
    set id [lindex [read_memory 0xE0042000 32 1] 0]
    set kb [lindex [read_memory 0x1FFFF7E0 16 1] 0]
    echo [format "V142_ID cpuid=0x%08X dbgmcu=0x%08X flash_kib=%d" $cpuid $id $kb]
    if {$cpuid != 0x411FC231 || $id != 0x20036410 || $kb != 64} {
        error "UNEXPECTED_CHIP"
    }
    set vectors [read_memory 0x08000000 32 2]
    if {[lindex $vectors 0] != 0x20000660 || [lindex $vectors 1] != 0x0800016D} {
        error "UNEXPECTED_FLASH_VECTOR"
    }
    poll
    set original_state [stm32f1x.cpu curstate]
    echo "V142_ORIGINAL_STATE=$original_state"
    if {$original_state eq "running"} {
        halt 2000
        set ::v142_halted_target 1
    } elseif {$original_state ne "halted"} {
        error "ORIGINAL_STATE_UNKNOWN"
    }
    if {[stm32f1x.cpu curstate] ne "halted"} {error "HALT_FAILED"}
    dump_image flash_before.bin 0x08000000 0x10000
    verify_image original_project.bin 0x08000000 bin
    echo "V142_ORIGINAL_VERIFIED"

    mdw 0x40010C04 3
    mdw 0x40021004 1
    mww 0x20004200 0 20
    load_image probe.bin 0x20003000 bin
    verify_image probe.bin 0x20003000 bin
    echo "V142_PROBE_SRAM_VERIFIED"
    reg control 0
    reg msp 0x20004FF0
    reg sp 0x20004FF0
    reg primask 1
    reg xpsr 0x01000000
    set ::v142_ram_entered 1
    resume 0x2000325C
    sleep 150
    halt 2000
    if {[stm32f1x.cpu curstate] ne "halted"} {error "PROBE_HALT_FAILED"}
    reg pc
    mdw 0x20004200 20
    dump_image ack_mailbox.bin 0x20004200 80
    dump_image flash_after.bin 0x08000000 0x10000
}

set probe_rc [catch {v142_test} reason]
if {$probe_rc} {echo "V142_ERROR=$reason"}
set restart_rc 0
if {$::v142_ram_entered} {
    set restart_rc [catch {
        reset run
        sleep 150
        if {[stm32f1x.cpu curstate] ne "running"} {error "FLASH_APP_NOT_RUNNING"}
        echo "V142_FLASH_APP_RUNNING"
    } restart_reason]
} elseif {$::v142_halted_target} {
    set restart_rc [catch {
        resume
        echo "V142_ORIGINAL_RESUMED"
    } restart_reason]
}
if {$restart_rc} {echo "V142_RESTART_ERROR=$restart_reason"}
echo "V142_COMPLETE probe_rc=$probe_rc restart_rc=$restart_rc"
shutdown
