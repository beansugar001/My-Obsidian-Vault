proc go {} {
    if {[catch {init} e]} { echo "VA_ERROR=init:$e"; return }
    echo "VA_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/verify_after_flash_20261120_1806/flash512.bin" 0x00000000 0x200
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/verify_after_flash_20261120_1806/w100.bin" 0x100 4
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/verify_after_flash_20261120_1806/w1ac.bin" 0x1ac 4
    echo "VA_DONE"
}
if {[catch {go} r]} { echo "VA_TOP_ERROR=$r" }
shutdown
