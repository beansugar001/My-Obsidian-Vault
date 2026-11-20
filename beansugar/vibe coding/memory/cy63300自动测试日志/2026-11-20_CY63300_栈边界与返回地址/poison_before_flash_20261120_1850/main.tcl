proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/poison_before_flash_20261120_1850/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/poison_before_flash_20261120_1850/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "PB_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "PB_STATE=[riscv.cpu curstate]"
    echo "PB_IMG=[format 0x%08X [rd 0x100]] [format 0x%08X [rd 0x1ac]]"
    mww 0x2000F000 0x11111111
    mww 0x2000F100 0x22222222
    mww 0x2001FEE8 0xBBBBBBBB
    mww 0x2001FEFC 0xAAAAAAAA
    mww 0x2001FEF0 0x99999999
    mww 0x2001FEF4 0x88888888
    echo "PB_RB=[format 0x%08X [rd 0x2000F000]] [format 0x%08X [rd 0x2000F100]] [format 0x%08X [rd 0x2001FEE8]] [format 0x%08X [rd 0x2001FEFC]] [format 0x%08X [rd 0x2001FEF0]] [format 0x%08X [rd 0x2001FEF4]]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/poison_before_flash_20261120_1850/frame_poison.bin" 0x2001FEE0 32
    echo "PB_DONE"
}
if {[catch {go} r]} { echo "PB_TOP_ERROR=$r" }
shutdown
