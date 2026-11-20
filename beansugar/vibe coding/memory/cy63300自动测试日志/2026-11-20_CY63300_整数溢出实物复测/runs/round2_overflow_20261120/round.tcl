proc rd {addr} {
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/tmp.bin" $addr 4
    set fh [open "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "OF2_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "OF2_STATE0=[riscv.cpu curstate]"
    echo [format "OF2_TAIL=0x%08X" [rd 0x1a8]]
    if {[rd 0x1a8] != 0xf75ff06f} { echo "OF2_IMAGE_MISMATCH"; return }
    echo "OF2_IMAGE_WORD_OK"
    mww 0x2000F000 0x00000000
    mww 0x2000F048 0xDEADBEEF
    mww 0x2000F04C 0xCAFEBABE
    mww 0x2000F060 0x11112222
    mww 0x2000F064 0x33334444
    mww 0x2000F070 0x77777777
    echo [format "OF2_POISON=0x%08X/0x%08X/0x%08X/0x%08X/0x%08X" [rd 0x2000F048] [rd 0x2000F04C] [rd 0x2000F060] [rd 0x2000F064] [rd 0x2000F070]]
    catch {reg pc 0x0}
    echo "OF2_PC=[reg pc]"
    catch {resume}
    set tried 0
    while {$tried < 80} {
        sleep 25
        if {[rd 0x2000F000] == 0x4D533132} { break }
        incr tried
    }
    echo "OF2_POLLS=$tried"
    echo [format "OF2_MARKER=0x%08X" [rd 0x2000F000]]
    echo [format "OF2_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]
    echo [format "OF2_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]
    echo [format "OF2_W7=0x%08X" [rd 0x2000F070]]
    echo [format "OF2_W14_W15=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/mbox_a.bin" 0x2000F000 104
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/mbox_b.bin" 0x2000F000 104
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/dest_a.bin" 0x2000F048 8
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/dest_b.bin" 0x2000F048 8
    echo "OF2_DONE"
}
if {[catch {go} e]} { echo "OF2_TOP_ERROR=$e" }
echo "OF2_SHUTDOWN_REQUEST"
shutdown
