proc go {} {
    if {[catch {init} e]} { echo "VS_ERROR=init:$e"; return }
    echo "VS_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/verify_state_20261120_1801/flash512.bin" 0x00000000 0x200
    echo "VS_DONE"
}
if {[catch {go} r]} { echo "VS_TOP_ERROR=$r" }
shutdown
