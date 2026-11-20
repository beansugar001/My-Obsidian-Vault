proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "C_ERROR=init:$e"; return }
    echo "C_STATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "C_MARKER=[format 0x%08X [rd 0x2000F000]]"
    echo "C_PHASE2=[format 0x%08X [rd 0x2000F110]]"
    echo "C_MCAUSE=[format 0x%08X [rd 0x2000F108]] MEPC=[format 0x%08X [rd 0x2000F10C]]"
    echo "C_R0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/mbox_a.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/res_a.bin" 0x2000F100 24
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/frame_a.bin" 0x2001FEE0 32
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/mbox_b.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/res_b.bin" 0x2000F100 24
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/check/frame_b.bin" 0x2001FEE0 32
    echo "C_DONE"
}
if {[catch {go} r]} { echo "C_TOP_ERROR=$r" }
shutdown
