# V115E: controlled ordering comparison; enable with a valid temporary target,
# then write OLED address. No TX FIFO access, so no bus transaction is requested.
set ::v115e_status "INCOMPLETE_OR_UNKNOWN";set ::v115e_wc 0;set ::v115e_hc 0
proc v115e_dr {r} {set o [capture [format "riscv dmi_read 0x%X" $r]];if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $r <$o>"};scan $x %x v;return [expr {$v&0xffffffff}]}
proc v115e_dw {r v label} {if {$r!=0x38&&$r!=0x39&&$r!=0x3C} {error "DMI_SETUP_WRITE_DENIED $r"};echo [format "V115E_DMI_WRITE %s reg=0x%02X value=0x%08X" $label $r [expr {$v&0xffffffff}]];riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v&0xffffffff}]]}
proc v115e_sb {label} {set s [v115e_dr 0x38];echo [format "V115E_SBCS %s=0x%08X" $label $s];if {$s&0x00607000} {error "SBA_BUSY_OR_ERROR $label"};return $s}
proc v115e_rd {a label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20140404 "${label}_READMODE";v115e_sb "${label}_MODE";v115e_dw 0x39 $a "${label}_ADDRESS";set v [v115e_dr 0x3C];v115e_sb "${label}_DONE";v115e_dw 0x38 0x20040404 "${label}_IDLE";v115e_sb "${label}_IDLE_CHECK";echo [format "V115E_MMIO_READ %s 0x%08X=0x%08X" $label $a $v];return $v}
proc v115e_wr {a v label} {v115e_sb "${label}_PRE";v115e_dw 0x38 0x20040404 "${label}_WRMODE";v115e_sb "${label}_MODE_IDLE";v115e_dw 0x39 $a "${label}_ADDRESS";v115e_sb "${label}_ADDRESS_IDLE";incr ::v115e_wc;echo [format "V115E_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v115e_wc $label];v115e_dw 0x3C $v "${label}_DATA";set done 0;for {set i 0} {$i<50} {incr i} {set s [v115e_dr 0x38];echo [format "V115E_WRITE_WAIT %s i=%d sbcs=0x%08X" $label $i $s];if {$s&0x00407000} {error "SBA_WRITE_ERROR $label"};if {($s&0x00200000)==0} {set done 1;break};sleep 1};if {!$done} {error "SBA_WRITE_TIMEOUT $label"};set got [v115e_rd $a "${label}_VERIFY"];if {$a==0x40002800} {if {($got&0xD)!=($v&0xD)} {error "READBACK_MISMATCH $label got=[format 0x%08X $got]"}} elseif {$got!=$v} {error "READBACK_MISMATCH $label got=[format 0x%08X $got]"};return $got}
proc v132_native_read {a label} {
 set out [capture [format "mdw 0x%08X 1" $a]]
 echo "NATIVE_RAW_${label}_BEGIN";echo $out;echo "NATIVE_RAW_${label}_END"
 if {![regexp -nocase {0x[0-9a-f]+\s*:\s*([0-9a-f]{8})} $out -> h]} {error "NATIVE_PARSE:$label"}
 scan $h %x v;set v [expr {$v&0xffffffff}]
 echo [format "NATIVE_SAMPLE %s=0x%08X" $label $v]
 return $v
}
proc v134_dir_sample {label} {
 set last -1
 for {set i 0} {$i<3} {incr i} {
  set old [v115e_rd 0x40000104 ${label}_DMI]
  set native [v132_native_read 0x40000104 ${label}_MDW]
  echo [format "V134_COMPARE phase=%s n=%d dmi=0x%X mdw=0x%X" $label $i $old $native]
  if {$old!=$native || ($last!=-1 && $last!=$native)} {error "V134_UNSTABLE_OR_DISAGREE:$label"}
  set last $native;sleep 20
 }
 return $last
}
proc v134_write {value parked label} {
 if {$::v115e_wc>=3 || ($value!=0 && $value!=8)} {error "V134_WRITE_BUDGET_OR_VALUE"}
 if {$parked} {if {[v115e_rd 0x40000100 ${label}_PARK_ODR]!=0xC} {error "V134_RELEASE_DATA_CHANGED"}}
 v115e_sb ${label}_PRE
 v115e_dw 0x38 0x20040404 ${label}_WRITE_MODE
 v115e_sb ${label}_MODE_IDLE
 v115e_dw 0x39 0x40000104 ${label}_DIR_ADDRESS
 v115e_sb ${label}_ADDRESS_IDLE
 incr ::v115e_wc
 echo [format "V134_TARGET_WRITE label=%s addr=0x40000104 value=0x%X parked=%d count=%d" $label $value $parked $::v115e_wc]
 v115e_dw 0x3C $value ${label}_DATA
 sleep 100
 v115e_sb ${label}_POST
 return [v134_dir_sample ${label}_READBACK]
}
set rc [catch {
 set init [capture {init}];echo "V115E_INIT_BEGIN";echo $init;echo "V115E_INIT_END";if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"};if {[jtag names] ne "riscv.cpu"||![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"};if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate];echo "V115E_CPU_INITIAL=$cpu";if {$cpu eq "running"} {capture {halt 2000};incr ::v115e_hc;set cpu [riscv.cpu curstate]};echo "V115E_CPU_FINAL=$cpu";if {$cpu ne "halted"||$::v115e_hc>1} {error "CPU_NOT_HALTED"};set dm [v115e_dr 0x11];echo [format "V115E_DMSTATUS=0x%08X" $dm];if {($dm&0x300)!=0x300||($dm&0xC00)!=0} {error "DMSTATUS_NOT_HALTED"};v115e_sb PREFLIGHT
 foreach {label a exp} {PERI_CLKEN 0x4002180C 1 PERI_RST 0x40021810 0 GPIOB_AFR1 0x40000168 0 GPIOB_OSOD 0x40000158 0xC GPIOB_ODR 0x40000100 0xC} {if {[v132_native_read $a $label]!=$exp} {error "V132_RELEASED_PRECONDITION_FAIL:$label"}}
 set before [v134_dir_sample BASELINE]
 if {$before!=0} {error "V134_DIR_NOT_INPUT_NO_WRITE"}
 set a [v134_write 8 0 A_NO_PARK]
 if {$a==8} {
  echo "V134_A_RESULT=WRITE_SUCCEEDED_WITHOUT_PARK"
  set ::v115e_status "A_SUCCEEDED_PARK_NOT_REQUIRED_THIS_TRIAL"
 } elseif {$a==0} {
  echo "V134_A_RESULT=WRITE_NOT_CONFIRMED"
  set b [v134_write 8 1 B_WITH_PARK]
  echo [format "V134_B_RESULT readback=0x%X" $b]
  if {$b==8} {set ::v115e_status "A_FAILED_B_SUCCEEDED_PARK_CORRELATION"} elseif {$b==0} {set ::v115e_status "A_AND_B_NOT_CONFIRMED"} else {error "V134_B_UNEXPECTED"}
 } else {error "V134_A_UNEXPECTED"}
 set final [v134_dir_sample PRE_RESTORE]
 if {$final==8} {
  set restored [v134_write 0 1 RELEASE_TO_INPUT]
  if {$restored!=0} {error "V134_INPUT_RESTORE_NOT_CONFIRMED"}
 } elseif {$final!=0} {error "V134_FINAL_UNEXPECTED"}
 echo "V134_FINAL_INPUT_CONFIRMED=1"
 v132_native_read 0x40000100 ODR_FINAL
 v132_native_read 0x40000158 OSOD_FINAL
 v132_native_read 0x40000104 DIR_FINAL


} err];if {$rc} {set ::v115e_status "FAIL_OR_UNKNOWN";echo "V115E_ERROR=$err"};set sbrc [catch {v115e_sb FINAL} sbv];echo [format "V115E_FINAL_SBCS rc=%d value=%s" $sbrc $sbv];set dmrc [catch {v115e_dr 0x11} dmv];echo [format "V115E_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv];echo [format "V115E_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v115e_status $::v115e_hc $::v115e_wc];echo "V115E_COMPLETE";shutdown





