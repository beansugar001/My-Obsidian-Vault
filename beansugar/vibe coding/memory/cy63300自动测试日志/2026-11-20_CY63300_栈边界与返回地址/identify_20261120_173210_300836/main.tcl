proc go {
    if {[catch {init} e]} { echo "ID_ERROR=init:$e"; return }
    echo "ID_JTAG=[jtag names]"
    echo "ID_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    if {[catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/identify_20261120_173210_300836/flash.bin" 0x00000000 0x200} e]} { echo "ID_ERROR=flash:$e" }
    echo "ID_PC=[reg pc]"
    echo "ID_SP=[reg sp]"
    echo "ID_RA=[reg ra]"
    for {set i 0} {$i < 32} {incr i} { }
    if {[catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/identify_20261120_173210_300836/sram_top.bin" 0x2001FFF0 16} e]} { echo "ID_ERROR=top:$e" }
    if {[catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/identify_20261120_173210_300836/sram_stack.bin" 0x2001FF00 16} e]} { echo "ID_ERROR=stack:$e" }
    if {[catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/identify_20261120_173210_300836/sram_mid.bin" 0x20010000 16} e]} { echo "ID_ERROR=mid:$e" }
    if {[catch {dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/identify_20261120_173210_300836/mbox.bin" 0x2000F000 128} e]} { echo "ID_ERROR=mbox:$e" }
    catch {resume}
    echo "ID_DONE"
}
if {[catch {go} r]} { echo "ID_TOP_ERROR=$r" }
shutdown
