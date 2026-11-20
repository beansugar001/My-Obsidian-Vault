proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reflash_reboot_20261120_1855/tmp2.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reflash_reboot_20261120_1855/tmp2.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "CK_ERROR=init:$e"; return }
    echo "CK_STATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "CK_MARKER=[format 0x%08X [rd 0x2000F000]]"
    echo "CK_PHASE2=[format 0x%08X [rd 0x2000F110]]"
    echo "CK_R0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"
    echo "CK_MCAUSE=[format 0x%08X [rd 0x2000F108]] MEPC=[format 0x%08X [rd 0x2000F10C]]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reflash_reboot_20261120_1855/mbox.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reflash_reboot_20261120_1855/res.bin" 0x2000F100 24
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reflash_reboot_20261120_1855/frame.bin" 0x2001FEE0 32
    echo "CK_DONE"
}
if {[catch {go} r]} { echo "CK_TOP_ERROR=$r" }
shutdown
