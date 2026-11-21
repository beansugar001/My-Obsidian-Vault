proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "R_ERROR=init:$e"; return }
    echo "R_STATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "R_STATE2=[riscv.cpu curstate]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/flash.bin" 0x0 0x400
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/mbox.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/res.bin" 0x2000F100 32
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-21_CY63300_栈对象登记/snapshot_20261121_103359/frame.bin" 0x2001FEE0 32
    echo "R_MARK=[format 0x%08X [rd 0x2000F000]]"
    echo "R_PHASE2=[format 0x%08X [rd 0x2000F110]]"
    echo "R_MCAUSE_MEM=[format 0x%08X [rd 0x2000F108]] MEPC_MEM=[format 0x%08X [rd 0x2000F10C]]"
    echo "R_R0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"
    echo "R_PLM0=[format 0x%08X [rd 0x70000000]] PLM1=[format 0x%08X [rd 0x70000004]]"
    echo "R_PLM2=[format 0x%08X [rd 0x70000008]] PLM3=[format 0x%08X [rd 0x7000000C]]"
    if {[catch {echo "R_DMSTATUS=[format 0x%08X [lindex [riscv dmi_read 0x11] 0]]"} e]} { echo "R_DM_ERR=$e" }
    catch {resume}
    echo "R_STATE3=[riscv.cpu curstate]"
    echo "R_DONE"
}
if {[catch {go} r]} { echo "R_TOP_ERROR=$r" }
shutdown
