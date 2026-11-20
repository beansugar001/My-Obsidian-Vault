proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/alias_20261120_173614_709798/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/alias_20261120_173614_709798/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc show {tag addr} {
    echo [format "AL %s 0x%08X 0x%08X" $tag $addr [rd $addr]]
}
proc go {} {
    if {[catch {init} e]} { echo "AL_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    show READ 0x20000000
    show READ 0x20000004
    show READ 0x20002000
    show READ 0x20008000
    show READ 0x20010000
    show READ 0x20018000
    show READ 0x2001FFF0
    show READ 0x20020000
    show READ 0x20020004
    show READ 0x20028000
    show READ 0x20030000
    show READ 0x20040000
    show READ 0x20080000
    show READ 0x200FFFFC
    show READ 0x20100000
    show READ 0x21000000
    catch {mww 0x2001FFF0 0x91490EBF}
    catch {mww 0x2001FFF4 0x19309FFE}
    catch {mww 0x2001FFF8 0x37F656DE}
    catch {mww 0x2001FFFC 0xBDC000DA}
    catch {mww 0x20010000 0xEFD0DF0E}
    catch {mww 0x20010004 0x9F4C95D4}
    show RESTORED 0x2001FFF0
    show RESTORED 0x2001FFF4
    show RESTORED 0x2001FFF8
    show RESTORED 0x2001FFFC
    show RESTORED 0x20010000
    show RESTORED 0x20010004
    catch {resume}
    echo "AL_DONE"
}
if {[catch {go} r]} { echo "AL_TOP_ERROR=$r" }
shutdown
