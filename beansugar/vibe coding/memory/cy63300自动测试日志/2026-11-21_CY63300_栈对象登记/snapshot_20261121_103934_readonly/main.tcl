proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "R_ERROR=init:$e"; return }
    echo "R_STATE0=[riscv.cpu curstate]"
    if {[catch {halt 2000} e]} { echo "R_HALT=FAIL:$e" }
    echo "R_STATE1=[riscv.cpu curstate]"
    echo "R_DMSTATUS=[format 0x%08X [rd 0x11]]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/flash.bin" 0x0 1024
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/mbox.bin" 0x2000F000 68
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/res.bin" 0x2000F100 28
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/frame.bin" 0x2001FEE0 32
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103934_readonly/plm.bin" 0x70000000 16
    echo "R_MARK=[format 0x%08X [rd 0x2000F000]]"
    echo "R_RES0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"
    echo "R_MCAUSE_MEM=[format 0x%08X [rd 0x2000F108]] MEPC_MEM=[format 0x%08X [rd 0x2000F10C]]"
    echo "R_TRAPMARK=[format 0x%08X [rd 0x2000F110]] PH2=[format 0x%08X [rd 0x2000F114]]"
    echo "R_FRAME8=[format 0x%08X [rd 0x2001FEE8]] FRAME28=[format 0x%08X [rd 0x2001FEFC]]"
    echo "R_PLM0=[format 0x%08X [rd 0x70000000]] PLM4=[format 0x%08X [rd 0x70000004]]"
    if {[catch {resume} e]} { echo "R_RESUME=FAIL:$e" } else { echo "R_RESUME=OK" }
    echo "R_STATE2=[riscv.cpu curstate]"
    echo "R_DONE"
}
if {[catch {go} r]} { echo "R_TOP_ERROR=$r" }
shutdown
