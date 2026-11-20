proc rd {addr} {
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/tmp.bin" $addr 4
    set fh [open "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "PJ_ERROR=init:$e"; return }
    echo "PJ_INIT_OK"
    echo "PJ_STATE0=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "PJ_PC_BEFORE=[reg pc]"
    mww 0x2000F048 0xDEADBEEF
    mww 0x2000F04C 0xCAFEBABE
    echo [format "PJ_POISON=0x%08X/0x%08X" [rd 0x2000F048] [rd 0x2000F04C]]
    echo "PJ_OLD_W14=0x[format %08X [rd 0x2000F038]] W15=0x[format %08X [rd 0x2000F03C]]"
    if {[catch {reg pc 0x0} e]} { echo "PJ_SETPC_ERROR=$e" }
    echo "PJ_PC_AFTER_SET=[reg pc]"
    if {[catch {resume} e]} { echo "PJ_RESUME_ERROR=$e" }
    echo "PJ_STATE1=[riscv.cpu curstate]"
    sleep 1500
    echo "PJ_STATE2=[riscv.cpu curstate]"
    echo [format "PJ_MARKER=0x%08X" [rd 0x2000F000]]
    echo [format "PJ_W14=0x%08X W15=0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]
    echo [format "PJ_BEFORE=0x%08X/0x%08X" [rd 0x2000F050] [rd 0x2000F054]]
    echo [format "PJ_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/dest_a.bin" 0x2000F048 8
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/mbox_a.bin" 0x2000F000 112
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/dest_b.bin" 0x2000F048 8
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/pc_jump_20261120_165310/mbox_b.bin" 0x2000F000 112
    echo "PJ_STATE3=[riscv.cpu curstate]"
    echo "PJ_DONE"
}
if {[catch {go} e]} { echo "PJ_ERROR=$e" }
echo "PJ_SHUTDOWN_REQUEST"
shutdown
