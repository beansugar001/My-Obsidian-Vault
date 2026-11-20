proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "R2_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    mww 0x2000F100 0x00000000
    mww 0x2000F104 0x00000000
    mww 0x2000F108 0x00000000
    mww 0x2000F10C 0x00000000
    mww 0x2000F110 0x00000000
    mww 0x2000F114 0x00000000
    mww 0x2001FEE8 0xBBBBBBBB
    mww 0x2001FEFC 0xAAAAAAAA
    echo [format "R2_PRE_RASLOT=0x%08X" [rd 0x2001FEFC]]
    echo [format "R2_PRE_GSELF=0x%08X" [rd 0x2001FEE8]]
    catch {reg pc 0x0}
    catch {resume}
    set tried 0
    while {$tried < 160} { sleep 25; if {[rd 0x2000F000] == 0x4d533141} { break }; incr tried }
    echo "R2_POLLS=$tried"
    sleep 60
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/mbox_a.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/res_a.bin" 0x2000F100 40
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/frame_a.bin" 0x2001FEE0 32
    sleep 45
    echo [format "R2_LATE_MARKER=0x%08X" [rd 0x2000F000]]
    echo [format "R2_LATE_PHASE2=0x%08X" [rd 0x2000F110]]
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/mbox_b.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/res_b.bin" 0x2000F100 40
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_poison_20261120_1820/frame_b.bin" 0x2001FEE0 32
    echo "R2_DONE"
}
if {[catch {go} r]} { echo "R2_TOP_ERROR=$r" }
shutdown
