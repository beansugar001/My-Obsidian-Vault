proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/range_20261120_173559_247686/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/cy63300自动测试日志/2026-11-20_CY63300_栈边界与返回地址/range_20261120_173559_247686/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc show {tag addr} {
    echo [format "RG %s 0x%08X 0x%08X" $tag $addr [rd $addr]]
}
proc go {} {
    if {[catch {init} e]} { echo "RG_ERROR=init:$e"; return }
    echo "RG_CURSTATE=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    show BEFORE 0x2001FFE0
    show BEFORE 0x2001FFF0
    show BEFORE 0x2001FFF4
    show BEFORE 0x2001FFF8
    show BEFORE 0x2001FFFC
    show BEFORE 0x20010000
    show BEFORE 0x20010004
    show BEFORE 0x20020000
    show BEFORE 0x20020004
    show BEFORE 0x2000F000
    catch {mww 0x2001FFF0 0xA5A5C002}
    catch {mww 0x2001FFF4 0xA5A5C003}
    catch {mww 0x2001FFF8 0xA5A5C004}
    catch {mww 0x2001FFFC 0xA5A5C005}
    catch {mww 0x20010000 0x5A5A0001}
    catch {mww 0x20010004 0x5A5A0002}
    catch {mww 0x20020000 0x5A5A0003}
    catch {mww 0x20020004 0x5A5A0004}
    show AFTER 0x2001FFE0
    show AFTER 0x2001FFF0
    show AFTER 0x2001FFF4
    show AFTER 0x2001FFF8
    show AFTER 0x2001FFFC
    show AFTER 0x20010000
    show AFTER 0x20010004
    show AFTER 0x20020000
    show AFTER 0x20020004
    show AFTER 0x2000F000
    show RESTORE_CHECK 0x2001FFE0
    show RESTORE_CHECK 0x2001FFF0
    show RESTORE_CHECK 0x2001FFF4
    show RESTORE_CHECK 0x2001FFF8
    show RESTORE_CHECK 0x2001FFFC
    show RESTORE_CHECK 0x20010000
    show RESTORE_CHECK 0x20010004
    show RESTORE_CHECK 0x20020000
    show RESTORE_CHECK 0x20020004
    show RESTORE_CHECK 0x2000F000
    catch {resume}
    echo "RG_DONE"
}
if {[catch {go} r]} { echo "RG_TOP_ERROR=$r" }
shutdown
