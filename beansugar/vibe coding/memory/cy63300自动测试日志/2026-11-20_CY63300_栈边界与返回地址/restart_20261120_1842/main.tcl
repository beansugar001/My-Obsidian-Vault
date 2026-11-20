proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/restart_20261120_1842/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/restart_20261120_1842/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "RS_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "RS_STATE=[riscv.cpu curstate]"
    echo "RS_IMG1=[format 0x%08X [rd 0x100]] [format 0x%08X [rd 0x1ac]]"
    mww 0x2000F000 0x11111111
    mww 0x2000F100 0x22222222
    mww 0x2001FEE8 0xBBBBBBBB
    mww 0x2001FEFC 0xAAAAAAAA
    echo "RS_RB=[format 0x%08X [rd 0x2000F000]] [format 0x%08X [rd 0x2000F100]] [format 0x%08X [rd 0x2001FEE8]] [format 0x%08X [rd 0x2001FEFC]]"
    if {[catch {reg pc 0x0} e]} { echo "RS_A_PCERR=$e" } else { echo "RS_A_PCOK=1" }
    catch {echo "RS_A_PCREAD=[reg pc]"}
    catch {resume}
    set t 0
    while {$t < 100} {
        sleep 25
        if {[rd 0x2000F000] == 0x4D533141} { break }
        incr t
    }
    echo "RS_A_POLLS=$t MARKER=[format 0x%08X [rd 0x2000F000]]"
    catch {halt 2000}
    echo "RS_R1=[format 0x%08X [rd 0x2000F100]] F8=[format 0x%08X [rd 0x2001FEE8]] F28=[format 0x%08X [rd 0x2001FEFC]] F0=[format 0x%08X [rd 0x2001FEE0]]"
    echo "RS_DONE"
}
if {[catch {go} r]} { echo "RS_TOP_ERROR=$r" }
shutdown
