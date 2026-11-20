proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/prepare/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/prepare/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "P_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "P_STATE=[riscv.cpu curstate]"
    echo "P_IMG=[format 0x%08X [rd 0x100]] [format 0x%08X [rd 0x1ac]]"
    mww 0x2000F000 0x00000000
    mww 0x2000F004 0x00000000
    mww 0x2000F008 0x00000000
    mww 0x2000F00C 0x00000000
    mww 0x2000F030 0x00000000
    mww 0x2000F034 0x00000000
    mww 0x2000F038 0x00000000
    mww 0x2000F03C 0x00000000
    mww 0x2000F040 0x00000000
    mww 0x2000F044 0x00000000
    mww 0x2000F048 0x00000000
    mww 0x2000F04C 0x00000000
    mww 0x2000F100 0x00000000
    mww 0x2000F104 0x00000000
    mww 0x2000F108 0x00000000
    mww 0x2000F10C 0x00000000
    mww 0x2000F110 0x00000000
    mww 0x2000F114 0x00000000
    mww 0x2001FEE8 0xBBBBBBBB
    mww 0x2001FEF0 0x99999999
    mww 0x2001FEF4 0x88888888
    mww 0x2001FEF8 0x77777777
    mww 0x2001FEFC 0xAAAAAAAA
    echo "P_RB_POISON=[format 0x%08X [rd 0x2001FEE8]] [format 0x%08X [rd 0x2001FEF0]] [format 0x%08X [rd 0x2001FEF4]] [format 0x%08X [rd 0x2001FEF8]] [format 0x%08X [rd 0x2001FEFC]]"
    echo "P_RB_MARK=[format 0x%08X [rd 0x2000F000]] R0=[format 0x%08X [rd 0x2000F100]] PH2=[format 0x%08X [rd 0x2000F110]]"
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/prepare/frame_prep.bin" 0x2001FEE0 32
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/round2_srst_20261120_181625_343804/prepare/mbox_prep.bin" 0x2000F000 64
    if {[catch {reset_config srst_only srst_nogate} e]} { echo "P_CFG=FAIL:$e" }
    if {[catch {reset run} e]} { echo "P_RESET=FAIL:$e" } else { echo "P_RESET=OK" }
    echo "P_DONE"
}
if {[catch {go} r]} { echo "P_TOP_ERROR=$r" }
shutdown
