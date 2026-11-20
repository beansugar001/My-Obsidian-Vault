proc go {} {
    if {[catch {init} e]} { echo "RP_ERROR=init:$e"; return }
    echo "RP_CURSTATE0=[riscv.cpu curstate]"
    if {[catch {reset halt} e]} { echo "RP_HALT=FAIL:$e" } else { echo "RP_HALT=OK" }
    echo "RP_STATE1=[riscv.cpu curstate]"
    catch {echo "RP_PC1=[reg pc]"}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe2_20261120_1828/m1.bin" 0x2000F000 16}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe2_20261120_1828/f1.bin" 0x2001FEE0 32}
    if {[catch {reset run} e]} { echo "RP_RUN=FAIL:$e" } else { echo "RP_RUN=OK" }
    sleep 300
    if {[catch {halt 2000} e]} { echo "RP_HALT2=FAIL:$e" } else { echo "RP_HALT2=OK" }
    echo "RP_STATE2=[riscv.cpu curstate]"
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe2_20261120_1828/m2.bin" 0x2000F000 16}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe2_20261120_1828/r2.bin" 0x2000F100 40}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe2_20261120_1828/f2.bin" 0x2001FEE0 32}
    echo "RP_DONE"
}
if {[catch {go} r]} { echo "RP_TOP_ERROR=$r" }
shutdown
