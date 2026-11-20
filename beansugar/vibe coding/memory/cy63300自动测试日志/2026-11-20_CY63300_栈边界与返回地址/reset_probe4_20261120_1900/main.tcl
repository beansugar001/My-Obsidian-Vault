proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe4_20261120_1900/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/reset_probe4_20261120_1900/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "R4_ERROR=init:$e"; return }
    echo "R4_STATE0=[riscv.cpu curstate]"
    echo "R4_PC0=[reg pc]"
    if {[catch {reset_config srst_only srst_nogate} e]} { echo "R4_CFG=FAIL:$e" } else { echo "R4_CFG=OK" }
    if {[catch {reset halt} e]} { echo "R4_HALT=FAIL:$e" } else { echo "R4_HALT=OK" }
    catch {echo "R4_PC1=[reg pc]"}
    echo "R4_STATE1=[riscv.cpu curstate]"
    echo "R4_MARK1=[format 0x%08X [rd 0x2000F000]]"
    if {[catch {resume} e]} { echo "R4_RES=FAIL:$e" } else { echo "R4_RES=OK" }
    sleep 400
    catch {halt 2000}
    echo "R4_MARK2=[format 0x%08X [rd 0x2000F000]] F16=[format 0x%08X [rd 0x2001FEF0]]"
    echo "R4_DONE"
}
if {[catch {go} r]} { echo "R4_TOP_ERROR=$r" }
shutdown
