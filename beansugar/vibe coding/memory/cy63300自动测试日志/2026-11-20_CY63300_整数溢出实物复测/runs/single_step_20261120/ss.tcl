proc rd {addr} {
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/single_step_20261120/tmp.bin" $addr 4
    set fh [open "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/single_step_20261120/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc dumpstate {tag} {
    echo "SS_$tag pc=[reg pc] a0=[reg a0] t0=[reg t0] t1=[reg t1] ra=[reg ra]"
}
proc setup {} {
    reg s0 0x2000F000
    reg s1 0x2000F040
    reg s6 0x13579BDF
    reg s7 0x2468ACE0
    mww 0x2000F048 0x2468ACE0
    mww 0x2000F04C 0x13579BDF
    mww 0x2000F060 0x11112222
    mww 0x2000F064 0x33334444
    reg a1 0x2000F060
    reg a0 0x00000000
}
proc go {} {
    if {[catch {init} e]} { echo "SS_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "SS_STATE=[riscv.cpu curstate]"
    setup
    reg pc 0x000000c0
    dumpstate START
    step; dumpstate S1
    step; dumpstate S2
    step; dumpstate S3
    step; dumpstate S4
    step; dumpstate S5
    step; dumpstate S6
    step; dumpstate S7
    step; dumpstate S8
    step; dumpstate S9
    step; dumpstate S10
    step; dumpstate S11
    step; dumpstate S12
    step; dumpstate S13
    echo [format "SS_SCRATCH=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]
    setup
    reg pc 0x000000a4
    dumpstate OS_START
    step; dumpstate OS1
    step; dumpstate OS2
    step; dumpstate OS3
    step; dumpstate OS4
    step; dumpstate OS5
    step; dumpstate OS6
    step; dumpstate OS7
    step; dumpstate OS8
    echo "SS_DONE"
}
if {[catch {go} e]} { echo "SS_TOP_ERROR=$e" }
shutdown
