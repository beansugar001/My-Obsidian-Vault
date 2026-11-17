# V115E: controlled ordering comparison; enable with a valid temporary target,
# then write OLED address. No TX FIFO access, so no bus transaction is requested.
set ::v115e_status "INCOMPLETE_OR_UNKNOWN";set ::v115e_wc 0;set ::v115e_hc 0
proc v115e_dr {r} {set o [capture [format "riscv dmi_read 0x%X" $r]];if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $r <$o>"};scan $x %x v;return [expr {$v&0xffffffff}]}
proc v115e_dw {r v label} {if {$r!=0x38&&$r!=0x39&&$r!=0x3C} {error "DMI_SETUP_WRITE_DENIED $r"};echo [format "V115E_DMI_WRITE %s reg=0x%02X value=0x%08X" $label $r [expr {$v&0xffffffff}]];riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v&0xffffffff}]]}
proc v115e_sb {label} {set s [v115e_dr 0x38];echo [format "V115E_SBCS %s=0x%08X" $label $s];if {$s&0x00607000} {error "SBA_BUSY_OR_ERROR $label"};return $s}
proc v115e_rd {a label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20140404 "${label}_READMODE";v115e_sb "${label}_MODE";v115e_dw 0x39 $a "${label}_ADDRESS";set v [v115e_dr 0x3C];v115e_sb "${label}_DONE";v115e_dw 0x38 0x20040404 "${label}_IDLE";v115e_sb "${label}_IDLE_CHECK";echo [format "V115E_MMIO_READ %s 0x%08X=0x%08X" $label $a $v];return $v}
proc v115e_wr {a v label} {
 if {!(($a==0x40000158 && $v==0xC) || ($a==0x40000100 && ($v==0 || $v==12)) || ($a==0x40000104 && ($v==0 || $v==4 || $v==8 || $v==12)))} {error "GPIO_WRITE_DENIED"}
 if {$::v115e_wc>=36} {error "GPIO_WRITE_BUDGET"}
 set park [expr {$a==0x40000100 ? 0x40000104 : 0x40000100}]
 set pv [v115e_rd $park ${label}_PARK_DIFFERENT_ADDRESS]
 echo [format "V135_PARK target=0x%08X via=0x%08X read=0x%08X" $a $park $pv]
 v115e_sb ${label}_PRE
 v115e_dw 0x38 0x20040404 ${label}_WRITE_MODE
 v115e_sb ${label}_MODE_IDLE
 v115e_dw 0x39 $a ${label}_TARGET_ADDRESS
 v115e_sb ${label}_ADDRESS_IDLE
 incr ::v115e_wc
 echo [format "V135_GPIO_WRITE addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v115e_wc $label]
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
 if {$got!=$v} {error "GPIO_READBACK_MISMATCH:$label expected=$v got=$got"}
 return $got
}
set rc [catch {
 set init [capture {init}];echo "V115E_INIT_BEGIN";echo $init;echo "V115E_INIT_END";if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"};if {[jtag names] ne "riscv.cpu"||![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"};if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate];echo "V115E_CPU_INITIAL=$cpu";if {$cpu eq "running"} {capture {halt 2000};incr ::v115e_hc;set cpu [riscv.cpu curstate]};echo "V115E_CPU_FINAL=$cpu";if {$cpu ne "halted"||$::v115e_hc>1} {error "CPU_NOT_HALTED"};set dm [v115e_dr 0x11];echo [format "V115E_DMSTATUS=0x%08X" $dm];if {($dm&0x300)!=0x300||($dm&0xC00)!=0} {error "DMSTATUS_NOT_HALTED"};v115e_sb PREFLIGHT
 foreach {label a exp} {PERI_CLKEN 0x4002180C 1 PERI_RST 0x40021810 0 GPIOB_DIR 0x40000104 0 GPIOB_AFR1 0x40000168 0 GPIOB_PUPD 0x4000015C 0x300 GPIOB_ODR 0x40000100 0xC} {if {[v115e_rd $a $label]!=$exp} {error "PRECONDITION_MISMATCH $label"}}
 set pins [v115e_rd 0x40000150 IDLE_INPUT]
 if {($pins&0xC)!=0xC} {error "INPUT_BUS_NOT_HIGH"}
 set ack "NOT_SAMPLED"
 v115e_wr 0x40000100 0x00000000 LOW_LATCH_WITH_BOTH_INPUT
 v115e_wr 0x40000158 0x0000000C OPEN_DRAIN
 # ODR stays ZERO. DIR bit=1 drives low, bit=0 releases/input.
 v115e_wr 0x40000104 0x00000008 START_SDA_LOW_SCL_INPUT
 for {set i 7} {$i>=0} {incr i -1} {
  set bit [expr {(0x78 >> $i)&1}]
  set sd [expr {$bit ? 0 : 8}]
  v115e_wr 0x40000104 [expr {4|$sd}] BIT_SETUP_SCL_LOW
  sleep 2
  v115e_wr 0x40000104 $sd BIT_CLOCK_SCL_INPUT
  sleep 2
  set pins [v115e_rd 0x40000150 BIT_INPUT]
  if {($pins&4)==0} {error "SCL_INPUT_LOW_DURING_CLOCK"}
  echo [format "GPIO_ADDRESS_BIT bit=%d data=%d dir=0x%X idr=0x%X" $i $bit $sd $pins]
  v115e_wr 0x40000104 [expr {4|$sd}] BIT_CLOCK_LOW
 }
 v115e_wr 0x40000104 0x00000004 ACK_SDA_INPUT_SCL_LOW
 v115e_wr 0x40000104 0x00000000 ACK_BOTH_INPUT
 sleep 2
 set dir [v115e_rd 0x40000104 ACK_DIR_VERIFY]
 set pins [v115e_rd 0x40000150 ACK_INPUT]
 if {$dir!=0 || ($pins&4)==0} {error "ACK_INPUT_INVALID"}
 set ack [expr {($pins&8) ? "NACK_INPUT_HIGH" : "ACK_INPUT_LOW"}]
 echo [format "GPIO_TRUE_INPUT_ACK result=%s dir=0x%X idr=0x%X" $ack $dir $pins]
 v115e_wr 0x40000104 0x00000004 ACK_CLOCK_FALL_BOTH_SAFE
 v115e_wr 0x40000104 0x0000000C STOP_BOTH_LOW
 v115e_wr 0x40000104 0x00000008 STOP_SCL_INPUT_SDA_LOW
 sleep 2
 set pins [v115e_rd 0x40000150 STOP_SCL_INPUT]
 if {($pins&4)==0} {error "STOP_SCL_NOT_HIGH"}
 v115e_wr 0x40000104 0x00000000 STOP_BOTH_INPUT
 set pins [v115e_rd 0x40000150 FINAL_INPUT]
 if {($pins&0xC)!=0xC} {error "FINAL_INPUT_NOT_HIGH"}
 set ::v115e_status "GPIO_FRAME_${ack}_STOP_INPUT_IDLE"

} err];if {$rc} {set ::v115e_status "FAIL_OR_UNKNOWN";echo "V115E_ERROR=$err";if {$::v115e_wc>0} {catch {v115e_wr 0x40000104 0 RELEASE_INPUT_ON_ERROR}}};set sbrc [catch {v115e_sb FINAL} sbv];echo [format "V115E_FINAL_SBCS rc=%d value=%s" $sbrc $sbv];set dmrc [catch {v115e_dr 0x11} dmv];echo [format "V115E_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv];echo [format "V115E_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v115e_status $::v115e_hc $::v115e_wc];echo "V115E_COMPLETE";shutdown




