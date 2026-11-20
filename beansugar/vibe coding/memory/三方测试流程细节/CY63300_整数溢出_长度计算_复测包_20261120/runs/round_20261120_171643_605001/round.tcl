proc rd {addr} {
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/tmp.bin" $addr 4
    set fh [open "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc go {} {
    if {[catch {init} e]} { echo "R_ERROR=init:$e"; return }
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    if {[rd 0x1a8] != 0xf75ff06f} { echo "R_IMAGE_MISMATCH"; return }
    echo "R_IMAGE_OK"
    mww 0x2000F000 0x00000000
    mww 0x2000F038 0xDEADBEEF
    mww 0x2000F03C 0xCAFEBABE
    mww 0x2000F010 0xCCCCCCCC
    mww 0x2000F014 0x55555555
    mww 0x2000F018 0xBBBBBBBB
    mww 0x2000F01C 0xAAAAAAAA
    mww 0x2000F050 0x66666666
    mww 0x2000F054 0x77777777
    mww 0x2000F058 0x11112222
    mww 0x2000F05C 0x33334444
    mww 0x2000F060 0x88888888
    mww 0x2000F064 0x99999999
    echo "R_POISON=[rd 0x2000f038] [rd 0x2000f03c] [rd 0x2000f010] [rd 0x2000f014] [rd 0x2000f018] [rd 0x2000f01c] [rd 0x2000f050] [rd 0x2000f054] [rd 0x2000f058] [rd 0x2000f05c] [rd 0x2000f060] [rd 0x2000f064]"
    catch {reg pc 0x0}
    catch {resume}
    set tried 0
    while {$tried < 80} {
        sleep 25
        if {[rd 0x2000F000] == 0x4d533132} { break }
        incr tried
    }
    echo "R_POLLS=$tried"
    echo [format "R_MARKER=0x%08X" [rd 0x2000F000]]
    echo [format "R_STATUS=0x%08X/0x%08X" [rd 0x2000F010] [rd 0x2000F018]]
    echo [format "R_PRESERVED=0x%08X/0x%08X" [rd 0x2000F014] [rd 0x2000F01C]]
    echo [format "R_BEFORE=0x%08X/0x%08X" [rd 0x2000F050] [rd 0x2000F054]]
    echo [format "R_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]
    echo [format "R_AFTER_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]
    echo [format "R_ORIG_DST=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/mbox_a.bin" 0x2000F000 104
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/dest_a.bin" 0x2000F048 8
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/mbox_b.bin" 0x2000F000 104
    dump_image "D:/obsidianvaults/笔记/beansugar/vibe coding/memory/三方测试流程细节/CY63300_整数溢出_长度计算_复测包_20261120/runs/round_20261120_171643_605001/dest_b.bin" 0x2000F048 8
    echo "R_DONE"
}
if {[catch {go} e]} { echo "R_TOP_ERROR=$e" }
shutdown
