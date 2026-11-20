proc go {} {
    if {[catch {init} e]} { echo "RP_ERROR=init:$e"; return }
    echo "RP_CURSTATE0=[riscv.cpu curstate]"
    foreach cmd {"reset halt" "reset init" "reset run"} {
        if {[catch {eval $cmd} e]} { echo "RP_CMD[$cmd]=FAIL:$e" } else { echo "RP_CMD[$cmd]=OK" }
        echo "RP_AFTER[$cmd]_STATE=[riscv.cpu curstate]"
        catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe_20261120_1826/after.bin" 0x2000F000 16}
        catch {echo "RP_AFTER[$cmd]_PC=[reg pc]"}
    }
    echo "RP_DONE"
}
if {[catch {go} r]} { echo "RP_TOP_ERROR=$r" }
shutdown
