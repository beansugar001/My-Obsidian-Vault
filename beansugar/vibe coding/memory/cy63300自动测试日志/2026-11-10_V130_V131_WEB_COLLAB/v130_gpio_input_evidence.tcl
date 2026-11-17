# V115E: controlled ordering comparison; enable with a valid temporary target,
# then write OLED address. No TX FIFO access, so no bus transaction is requested.
set ::v115e_status "INCOMPLETE_OR_UNKNOWN";set ::v115e_wc 0;set ::v115e_hc 0
proc v115e_dr {r} {set o [capture [format "riscv dmi_read 0x%X" $r]];if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $r <$o>"};scan $x %x v;return [expr {$v&0xffffffff}]}
proc v115e_dw {r v label} {if {$r!=0x38&&$r!=0x39&&$r!=0x3C} {error "DMI_SETUP_WRITE_DENIED $r"};echo [format "V115E_DMI_WRITE %s reg=0x%02X value=0x%08X" $label $r [expr {$v&0xffffffff}]];riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v&0xffffffff}]]}
proc v115e_sb {label} {set s [v115e_dr 0x38];echo [format "V115E_SBCS %s=0x%08X" $label $s];if {$s&0x00607000} {error "SBA_BUSY_OR_ERROR $label"};return $s}
proc v115e_rd {a label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20140404 "${label}_READMODE";v115e_sb "${label}_MODE";v115e_dw 0x39 $a "${label}_ADDRESS";set v [v115e_dr 0x3C];v115e_sb "${label}_DONE";v115e_dw 0x38 0x20040404 "${label}_IDLE";v115e_sb "${label}_IDLE_CHECK";echo [format "V115E_MMIO_READ %s 0x%08X=0x%08X" $label $a $v];return $v}
proc v115e_wr {a v label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20040404 "${label}_WRMODE";v115e_sb "${label}_MODE_IDLE";v115e_dw 0x39 $a "${label}_ADDRESS";v115e_sb "${label}_ADDRESS_IDLE";incr ::v115e_wc;echo [format "V115E_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v115e_wc $label];v115e_dw 0x3C $v "${label}_DATA";set done 0;for {set i 0} {$i<50} {incr i} {set s [v115e_dr 0x38];echo [format "V115E_WRITE_WAIT %s i=%d sbcs=0x%08X" $label $i $s];if {$s&0x00407000} {error "SBA_WRITE_ERROR $label"};if {($s&0x00200000)==0} {set done 1;break};sleep 1};if {!$done} {error "SBA_WRITE_TIMEOUT $label"};set got [v115e_rd $a "${label}_VERIFY"];if {$a==0x40002800} {if {($got&0xD)!=($v&0xD)} {error "READBACK_MISMATCH $label got=[format 0x%08X $got]"}} elseif {$got!=$v} {error "READBACK_MISMATCH $label got=[format 0x%08X $got]"};return $got}
set rc [catch {
 set init [capture {init}];echo "V115E_INIT_BEGIN";echo $init;echo "V115E_INIT_END";if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"};if {[jtag names] ne "riscv.cpu"||![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"};if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate];echo "V115E_CPU_INITIAL=$cpu";if {$cpu eq "running"} {capture {halt 2000};incr ::v115e_hc;set cpu [riscv.cpu curstate]};echo "V115E_CPU_FINAL=$cpu";if {$cpu ne "halted"||$::v115e_hc>1} {error "CPU_NOT_HALTED"};set dm [v115e_dr 0x11];echo [format "V115E_DMSTATUS=0x%08X" $dm];if {($dm&0x300)!=0x300||($dm&0xC00)!=0} {error "DMSTATUS_NOT_HALTED"};v115e_sb PREFLIGHT
 foreach {label a exp} {PERI_CLKEN 0x4002180C 1 PERI_RST 0x40021810 0 GPIOB_DIR 0x40000104 0 GPIOB_AFR1 0x40000168 0 GPIOB_PUPD 0x4000015C 0 GPIOB_ODR 0x40000100 0} {set got [v115e_rd $a $label];if {$got!=$exp} {error "PRECONDITION_MISMATCH $label"}}
 for {set i 0} {$i<3} {incr i} {sleep 10;set v [v115e_rd 0x40000150 INPUT_NO_PULL];echo [format "INPUT_SAMPLE phase=NO_PULL n=%d value=0x%08X" $i $v]}
 v115e_wr 0x4000015C 0x00000300 INPUT_PULLUP
 for {set i 0} {$i<3} {incr i} {sleep 10;set v [v115e_rd 0x40000150 INPUT_PULLUP];echo [format "INPUT_SAMPLE phase=PULLUP_ODR_ZERO n=%d value=0x%08X" $i $v]}
 v115e_wr 0x40000100 0x0000000C INPUT_LATCH_HIGH
 for {set i 0} {$i<3} {incr i} {sleep 10;set v [v115e_rd 0x40000150 INPUT_ODR_HIGH];echo [format "INPUT_SAMPLE phase=PULLUP_ODR_HIGH n=%d value=0x%08X" $i $v]}
 v115e_wr 0x40000100 0x00000000 INPUT_LATCH_ZERO
 for {set i 0} {$i<3} {incr i} {sleep 10;set v [v115e_rd 0x40000150 INPUT_ODR_ZERO];echo [format "INPUT_SAMPLE phase=PULLUP_ODR_ZERO_FINAL n=%d value=0x%08X" $i $v]}
 set dir [v115e_rd 0x40000104 DIR_FINAL];set af [v115e_rd 0x40000168 AF_FINAL];set clk [v115e_rd 0x4002180C CLOCK_FINAL]
 if {$dir!=0 || $af!=0 || $clk!=1} {error "INPUT_PATH_FINAL_STATE_MISMATCH"}
 set ::v115e_status "INPUT_PATH_SAMPLING_COMPLETE_REVIEW_VALUES"

} err];if {$rc} {set ::v115e_status "FAIL_OR_UNKNOWN";echo "V115E_ERROR=$err"};set sbrc [catch {v115e_sb FINAL} sbv];echo [format "V115E_FINAL_SBCS rc=%d value=%s" $sbrc $sbv];set dmrc [catch {v115e_dr 0x11} dmv];echo [format "V115E_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv];echo [format "V115E_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v115e_status $::v115e_hc $::v115e_wc];echo "V115E_COMPLETE";shutdown

