proc rd {addr} {
    dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/tmp.bin" $addr 4
    set fh [open "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
if {[catch {init} e]} { echo "ID_ERROR=$e" }
echo "ID_STATE=[riscv.cpu curstate]"
echo [format "ID_1A0=0x%08X ID_1A4=0x%08X ID_1AC=0x%08X" [rd 0x1a0] [rd 0x1a4] [rd 0x1ac]]
dump_image "C:/Users/24796/Documents/组/CY63300_内存安全首轮/recheck_20261120/round2_overflow_20261120/flash_428.bin" 0x0 428
echo "ID_SHUTDOWN"
shutdown
