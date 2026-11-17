proc v158_identity {} {
    init
    poll
    set cpuid [lindex [read_memory 0xE000ED00 32 1] 0]
    set chip [lindex [read_memory 0xE0042000 32 1] 0]
    if {[target current] ne "stm32f1x.cpu" ||
        $cpuid != 0x411FC231 || $chip != 0x20036410} {error "WRONG_TARGET"}
}

proc v158_header {} {
    set crh [lindex [read_memory 0x40010C04 32 1] 0]
    set header [read_memory 0x20000000 32 8]
    set magic [lindex $header 0]
    set state [lindex $header 1]
    set count [lindex $header 3]
    set pins [lindex $header 6]
    echo [format "V158_MONITOR crh=0x%08X magic=0x%08X state=%d count=%d pins=0x%03X" $crh $magic $state $count $pins]
    if {($crh & 0xFF) != 0x44 || $magic != 0x158B0501 || $state < 1 ||
        $state > 3 || $count > 4096} {error "MONITOR_NOT_HIGH_Z"}
    return $header
}

proc v158_action {action} {
    v158_identity
    switch -- $action {
        load {
            set sp [lindex [read_memory 0x08000000 32 1] 0]
            if {$sp != 0x20000660} {error "UNEXPECTED_FLASH_VECTOR"}
            set cpu [stm32f1x.cpu curstate]
            if {$cpu eq "running"} {halt 2000}
            if {[stm32f1x.cpu curstate] ne "halted"} {error "HALT_FAILED"}
            mww 0x20000000 0 8
            load_image capture.bin 0x20004800 bin
            verify_image capture.bin 0x20004800 bin
            reg control 0
            reg msp 0x20004FF0
            reg sp 0x20004FF0
            reg primask 1
            reg xpsr 0x01000000
            resume 0x20004800
            sleep 25
            set header [v158_header]
            if {[lindex $header 1] != 1 || [lindex $header 6] != 0x300} {
                error "MONITOR_NOT_IDLE_HIGH"
            }
        }
        arm {
            if {[stm32f1x.cpu curstate] ne "running"} {error "MONITOR_NOT_RUNNING"}
            for {set i 0} {$i < 3} {incr i} {
                set header [v158_header]
                if {[lindex $header 1] != 1 || [lindex $header 6] != 0x300} {
                    error "CONNECTED_BUS_NOT_IDLE_HIGH"
                }
                sleep 10
            }
            echo "V158_ARM_BEGIN host_ms=[clock milliseconds]"
            mww 0x20000008 1
            sleep 20
            set header [v158_header]
            if {[lindex $header 1] != 2 || [lindex $header 5] != 0x300} {
                error "MONITOR_NOT_ARMED_IDLE"
            }
            echo "V158_ARM_END host_ms=[clock milliseconds]"
        }
        read {
            if {[stm32f1x.cpu curstate] eq "running"} {halt 2000}
            if {[stm32f1x.cpu curstate] ne "halted"} {error "CAPTURE_HALT_FAILED"}
            set header [v158_header]
            if {[lindex $header 1] < 2} {error "CAPTURE_NOT_ARMED"}
            mdw 0x40010C08 1
            dump_image capture_mailbox.bin 0x20000000 16416
        }
        default {error "UNKNOWN_ACTION"}
    }
}

set rc [catch {v158_action $v158_phase} detail]
if {$rc} {echo "V158_ERROR=$detail"}
echo "V158_COMPLETE phase=$v158_phase rc=$rc"
shutdown
