proc wait_step {gate} {
    set start [ms]
    while {[ms] - $start < 120000} {
        if {[file exists "$::env(GPIO_GATE)/stop"]} {return 0}
        if {[file exists "$::env(GPIO_GATE)/$gate"]} {return 1}
        sleep 100 busy
    }
    echo STEP_EXPIRED
    return 0
}

proc staged_read {} {
    debug_level 3
    echo STEP_INIT_COMPLETE
    if {![wait_step dmstatus]} {return}
    echo STEP_DMSTATUS_BEGIN
    set raw [capture {riscv dmi_read 0x11}]
    if {![regexp -nocase {^\s*0x([0-9a-f]+)\s*$} $raw -> hex]} {error "DMSTATUS_PARSE <$raw>"}
    scan $hex %x status
    echo [format "STEP_DMSTATUS_COMPLETE 0x%08X" $status]
    if {($status & 0xf80) != 0xc80} {error HART_NOT_RUNNING}
    if {![wait_step sram]} {return}
    echo STEP_SRAM_BEGIN
    echo [format "STEP_SRAM_COMPLETE 0x%08X" [read_word 0x2000F010]]
    wait_step finish
}
if {[catch {staged_read} detail]} {echo "STEP_ERROR=$detail"}
echo STEP_SESSION_END
shutdown
