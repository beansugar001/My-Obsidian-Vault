proc go {} {
    if {[catch {init} e]} { echo "PB_ERROR=init:$e"; return }
    echo "PB_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    foreach r {pc sp ra gp tp a0 a1 s0 s1 s10 t0 t1 t2 t5 mcause mepc} {
        if {[catch {reg $r} v]} { echo "PB_REG_$r=ERR:$v" } else { echo "PB_REG_$r=$v" }
    }
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/frame1.bin" 0x2001FEE0 64}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/sp1.bin" 0x2001FF00 32}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/res1.bin" 0x2000F100 32}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/src1.bin" 0x2000F040 16}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/frame2.bin" 0x2001FEE0 64}
    catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/probe_20261120_1812/res2.bin" 0x2000F100 32}
    echo "PB_DONE"
}
if {[catch {go} r]} { echo "PB_TOP_ERROR=$r" }
shutdown
