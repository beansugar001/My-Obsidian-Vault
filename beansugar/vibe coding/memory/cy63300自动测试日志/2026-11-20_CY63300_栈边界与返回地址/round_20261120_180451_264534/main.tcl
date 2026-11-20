proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "ST_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    if {[rd 0x100] != 0x4d5332b7 || [rd 0x1ac] != 0x005d2823} { echo "ST_IMAGE_MISMATCH"; return }
    echo "ST_IMAGE_WORD_OK"
    echo [format "ST_PRE_MARKER=0x%08X" [rd 0x2000F000]]
    mww 0x2000F000 0x00000000
    mww 0x2000F100 0x00000000
    catch {reg pc 0x0}
    catch {resume}
    set tried 0
    while {$tried < 120} {
        sleep 25
        if {[rd 0x2000F000] == 0x4d533141} { break }
        incr tried
    }
    echo "ST_POLLS=$tried"
    sleep 60
    echo [format "ST_MARKER=0x%08X" [rd 0x2000F000]]
    echo [format "ST_PHASE2=0x%08X" [rd 0x2000F110]]
    echo [format "ST_MCAUSE=0x%08X" [rd 0x2000F108]]
    echo [format "ST_MEPC=0x%08X" [rd 0x2000F10C]]
    echo [format "ST_RA_OK=0x%08X" [rd 0x2000F100]]
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/mbox_a.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/res_a.bin" 0x2000F100 24
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/frame_a.bin" 0x2001FEE0 32
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/mbox_b.bin" 0x2000F000 64
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/res_b.bin" 0x2000F100 24
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round_20261120_180451_264534/frame_b.bin" 0x2001FEE0 32
    echo "ST_DONE"
}
if {[catch {go} r]} { echo "ST_TOP_ERROR=$r" }
echo "ST_SHUTDOWN_REQUEST"
shutdown
