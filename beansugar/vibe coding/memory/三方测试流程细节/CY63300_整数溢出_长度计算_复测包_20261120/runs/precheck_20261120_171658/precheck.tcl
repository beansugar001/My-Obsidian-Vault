proc go {} {
    if {[catch {init} e]} { echo "PC_ERROR=$e"; return }
    catch {halt 2000}
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/precheck_20261120_171658/flash.bin" 0x0 512
    echo "PC_DONE"
}
if {[catch {go} e]} { echo "PC_TOP_ERROR=$e" }
shutdown
