# V115E: controlled ordering comparison; enable with a valid temporary target,
# then write OLED address. No TX FIFO access, so no bus transaction is requested.
set ::v115e_status "INCOMPLETE_OR_UNKNOWN";set ::v115e_wc 0;set ::v115e_hc 0
proc v115e_dr {r} {set o [capture [format "riscv dmi_read 0x%X" $r]];if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $r <$o>"};scan $x %x v;return [expr {$v&0xffffffff}]}
proc v115e_dw {r v label} {if {$r!=0x38&&$r!=0x39&&$r!=0x3C} {error "DMI_SETUP_WRITE_DENIED $r"};echo [format "V115E_DMI_WRITE %s reg=0x%02X value=0x%08X" $label $r [expr {$v&0xffffffff}]];riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v&0xffffffff}]]}
proc v115e_sb {label} {set s [v115e_dr 0x38];echo [format "V115E_SBCS %s=0x%08X" $label $s];if {$s&0x00607000} {error "SBA_BUSY_OR_ERROR $label"};return $s}
proc v115e_rd {a label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20140404 "${label}_READMODE";v115e_sb "${label}_MODE";v115e_dw 0x39 $a "${label}_ADDRESS";set v [v115e_dr 0x3C];v115e_sb "${label}_DONE";v115e_dw 0x38 0x20040404 "${label}_IDLE";v115e_sb "${label}_IDLE_CHECK";echo [format "V115E_MMIO_READ %s 0x%08X=0x%08X" $label $a $v];return $v}
proc v115e_wr {a v label} {
 if {!(($a==0x4002180C && $v==0x21) || ($a==0x40000100 && $v==0xC) || ($a==0x40000104 && $v==0xC) || ($a==0x40000168 && $v==0x6C0) || (($a==0x40002810 || $a==0x40002814) && $v==0x3E7) || ($a==0x40002828 && $v==0) || ($a==0x40002838 && $v==5) || ($a==0x40002800 && ($v==0xC || $v==0xD)) || ($a==0x40002820 && $v==1) || ($a==0x40002824 && $v==0x3C))} {error "V136_WRITE_DENIED"}
 if {$::v115e_wc>=12} {error "GPIO_WRITE_BUDGET"}
 set park [expr {$a==0x40000100 ? 0x40000104 : 0x40000100}]
 set pv [v115e_rd $park ${label}_PARK_DIFFERENT_ADDRESS]
 echo [format "V136_PARK target=0x%08X via=0x%08X read=0x%08X" $a $park $pv]
 v115e_sb ${label}_PRE
 v115e_dw 0x38 0x20040404 ${label}_WRITE_MODE
 v115e_sb ${label}_MODE_IDLE
 v115e_dw 0x39 $a ${label}_TARGET_ADDRESS
 v115e_sb ${label}_ADDRESS_IDLE
 incr ::v115e_wc
 echo [format "V136_TARGET_WRITE addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v115e_wc $label]
 v115e_dw 0x3C $v ${label}_DATA
 set done 0
 for {set n 0} {$n<50} {incr n} {
  set sb [v115e_dr 0x38]
  if {$sb&0x00407000} {error "GPIO_SBA_ERROR"}
  if {($sb&0x00200000)==0} {set done 1;break}
  sleep 1
 }
 if {!$done} {error "GPIO_SBA_TIMEOUT"}
 set got [v115e_rd $a ${label}_VERIFY]
 if {$a==0x40002800} {if {($got&0xD)!=($v&0xD)} {error "MODULE_READBACK_MISMATCH:$label got=$got"}} elseif {$got!=$v} {error "READBACK_MISMATCH:$label expected=$v got=$got"}
 return $got
}
set rc [catch {
 set init [capture {init}];echo "V115E_INIT_BEGIN";echo $init;echo "V115E_INIT_END";if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"};if {[jtag names] ne "riscv.cpu"||![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"};if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate];echo "V115E_CPU_INITIAL=$cpu";if {$cpu eq "running"} {capture {halt 2000};incr ::v115e_hc;set cpu [riscv.cpu curstate]};echo "V115E_CPU_FINAL=$cpu";if {$cpu ne "halted"||$::v115e_hc>1} {error "CPU_NOT_HALTED"};set dm [v115e_dr 0x11];echo [format "V115E_DMSTATUS=0x%08X" $dm];if {($dm&0x300)!=0x300||($dm&0xC00)!=0} {error "DMSTATUS_NOT_HALTED"};v115e_sb PREFLIGHT
 foreach {label a exp} {PERI_CLKEN 0x4002180C 1 PERI_RST 0x40021810 0 GPIOB_DIR 0x40000104 0 GPIOB_AFR1 0x40000168 0 GPIOB_PUPD 0x4000015C 0x300 GPIOB_ODR 0x40000100 0 GPIOB_OSOD 0x40000158 0xC} {if {[v115e_rd $a $label]!=$exp} {error "V136_PRECONDITION:$label"}}
 v115e_wr 0x4002180C 0x00000021 GPIO_I2C_CLOCK
 foreach {label a exp} {PERI_RST 0x40021810 0 MODULE_CTRL 0x40002800 2 FIFO_STA 0x4000280C 5 I2C_STA 0x4000283C 0 RAW_INTR 0x40002858 0} {if {[v115e_rd $a $label]!=$exp} {error "V136_I2C_NOT_CLEAN:$label"}}
 v115e_wr 0x40000100 0x0000000C GPIO_RELEASE_LATCH
 v115e_wr 0x40000104 0x0000000C GPIO_OUTPUT_ENABLE
 v115e_wr 0x40000168 0x000006C0 PAD8_PAD9_AF3
 v115e_wr 0x40002810 0x000003E7 CLK_DIV0
 v115e_wr 0x40002814 0x000003E7 CLK_DIV1
 v115e_wr 0x40002828 0x00000000 MCTR_7BIT_SCL_L
 v115e_wr 0x40002838 0x00000005 HOLD5
 v115e_wr 0x40002800 0x0000000C FIFO_ENABLE
 v115e_wr 0x40002820 0x00000001 MASTER_MODE
 v115e_wr 0x40002824 0x0000003C OLED_ADDRESS_DIRECT
 set before [v115e_rd 0x40002800 MODULE_BEFORE_ENABLE]
 if {$before!=0xE} {error "V136_FIFO_MODULE_UNEXPECTED"}
 v115e_wr 0x40002800 0x0000000D I2C_ENABLE_DIRECT_3C
 foreach {label a exp} {MODULE_FINAL 0x40002800 0xF ADDR_FINAL 0x40002824 0x3C FIFO_FINAL 0x4000280C 5 STA_FINAL 0x4000283C 0 RAW_FINAL 0x40002858 0 RST_FINAL 0x40021810 0 PUPD_FINAL 0x4000015C 0x300} {if {[v115e_rd $a $label]!=$exp} {error "V136_FINAL_MISMATCH:$label"}}
 set ::v115e_status "PASS_DIRECT_3C_ENABLE_PARKED_FIFO_EMPTY"
} err];if {$rc} {set ::v115e_status "FAIL_OR_UNKNOWN";echo "V115E_ERROR=$err";if {$::v115e_wc>0} {catch {v115e_wr 0x40000104 0 RELEASE_INPUT_ON_ERROR}}};set sbrc [catch {v115e_sb FINAL} sbv];echo [format "V115E_FINAL_SBCS rc=%d value=%s" $sbrc $sbv];set dmrc [catch {v115e_dr 0x11} dmv];echo [format "V115E_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv];echo [format "V115E_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v115e_status $::v115e_hc $::v115e_wc];echo "V115E_COMPLETE";shutdown





