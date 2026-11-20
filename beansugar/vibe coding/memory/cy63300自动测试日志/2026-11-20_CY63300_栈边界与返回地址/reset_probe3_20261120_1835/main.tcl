proc go {} {
    if {[catch {init} e]} { echo "RP_ERROR=init:$e"; return }
    if {[catch {riscv set_reset_timeout_sec 5} e]} { echo "RP_TMO=FAIL:$e" } else { echo "RP_TMO=OK" }
    if {[catch {reset halt} e]} { echo "RP_HALT=FAIL:$e" } else { echo "RP_HALT=OK" }
    echo "RP_STATE1=[riscv.cpu curstate]"
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe3_20261120_1835/m_halt.bin" 0x2000F000 16}
    if {[catch {reset run} e]} { echo "RP_RUN=FAIL:$e" } else { echo "RP_RUN=OK" }
    sleep 500
    if {[catch {halt 5000} e]} { echo "RP_HALT2=FAIL:$e" } else { echo "RP_HALT2=OK" }
    echo "RP_STATE2=[riscv.cpu curstate]"
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe3_20261120_1835/m_after.bin" 0x2000F000 16}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe3_20261120_1835/f_after.bin" 0x2001FEE0 32}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe3_20261120_1835/r_after.bin" 0x2000F100 40}
    echo "RP_DONE"
}
if {[catch {go} r]} { echo "RP_TOP_ERROR=$r" }
shutdown
