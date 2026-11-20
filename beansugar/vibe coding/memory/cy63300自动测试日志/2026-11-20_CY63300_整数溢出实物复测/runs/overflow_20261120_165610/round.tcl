proc rd {addr} {
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/tmp.bin" $addr 4
    set fh [open "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "OF_ERROR=init:$e"; return }
    echo "OF_INIT_OK"
    echo "OF_STATE0=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "OF_PC_BEFORE=[reg pc]"
    if {[rd 0x1a8] != 0xf75ff06f} { echo "OF_IMAGE_MISMATCH"; return }
    echo "OF_IMAGE_WORD_OK"
    catch {mww 0x2000F000 0x00000000}
    mww 0x2000F048 0xDEADBEEF
    mww 0x2000F04C 0xCAFEBABE
    echo [format "OF_POISON_READ=0x%08X/0x%08X" [rd 0x2000F048] [rd 0x2000F04C]]
    if {[catch {reg pc 0x0} e]} { echo "OF_SETPC_ERROR=$e" }
    echo "OF_PC_AFTER_SET=[reg pc]"
    if {[catch {resume} e]} { echo "OF_RESUME_ERROR=$e" }
    set tried 0
    while {$tried < 80} {
        sleep 25
        if {[rd 0x2000F000] == 0x4d533132} { break }
        incr tried
    }
    echo "OF_POLLS=$tried"
    echo [format "OF_MARKER=0x%08X" [rd 0x2000F000]]
    echo "OF_STATE1=[riscv.cpu curstate]"
    echo [format "OF_W14_W15=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]
    echo [format "OF_BEFORE=0x%08X/0x%08X" [rd 0x2000F050] [rd 0x2000F054]]
    echo [format "OF_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]
    echo [format "OF_AFTER_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/dest_a.bin" 0x2000F048 8
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/mbox_a.bin" 0x2000F000 104
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/dest_b.bin" 0x2000F048 8
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/overflow_20261120_165610/mbox_b.bin" 0x2000F000 104
    echo "OF_STATE2=[riscv.cpu curstate]"
    echo "OF_DONE"
}
if {[catch {go} e]} { echo "OF_TOP_ERROR=$e" }
echo "OF_SHUTDOWN_REQUEST"
shutdown
