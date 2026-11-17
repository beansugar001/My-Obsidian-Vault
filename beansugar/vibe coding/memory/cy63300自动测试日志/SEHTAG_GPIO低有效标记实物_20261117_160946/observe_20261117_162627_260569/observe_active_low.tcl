proc gpio_snapshot {label} {
    set fields {}
    foreach addr {0x40000200 0x40000204 0x2000F000 0x2000F004 0x2000F010 0x2000F110 0x2000F02C} {
        lappend fields [read_word $addr]
    }
    if {[riscv.cpu curstate] ne "running"} {error HART_NOT_RUNNING}
    echo [format "SYNC_STATE %s %08X %08X %08X %08X %08X %08X %08X" $label {*}$fields]
    return $fields
}

proc synchronized_read {} {
    poll off
    if {([read_word 0x4002180c] & 1) == 0 ||
        ([read_word 0x40000258] & 0xc3) != 3 ||
        ([read_word 0x4000025c] & 0xc3) != 0xc0} {
        error GPIO_CONFIG_MISMATCH
    }
    set initial [gpio_snapshot INITIAL]
    if {([lindex $initial 0] & 3) != 0 || ([lindex $initial 1] & 1) != 1 ||
        [lindex $initial 6] != 0x52547000} {
        error COMPLETION_OR_GPIO_MISMATCH
    }
    echo SYNC_QUIET_BEGIN
    sleep 5000 busy
    gpio_snapshot BEFORE_ACTIVE
    echo SYNC_ACTIVE_BEGIN
    set start [ms]
    set count 0
    while {[ms] - $start < 10000} {
        read_word 0x2000F010
        read_word 0x2000F110
        incr count 2
    }
    echo "SYNC_ACTIVE_READS $count [expr {[ms] - $start}]"
    gpio_snapshot AFTER_ACTIVE
    sleep 5000 busy
    gpio_snapshot FINAL
}

if {[catch {synchronized_read} detail]} {
    echo "SYNC_ERROR=$detail"
} else {
    echo SYNC_COMPLETE
}
shutdown
