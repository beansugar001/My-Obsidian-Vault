proc go {} {
    if {[catch {init} e]} { echo "ST_ERROR=init:$e"; return }
    echo "ST_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/flash_20261120_175937_321462/pre_snapshot.bin" 0x00000000 0x10000
    catch {resume}
    echo "ST_SNAPSHOT_DONE"
}
if {[catch {go} r]} { echo "ST_TOP_ERROR=$r" }
shutdown
