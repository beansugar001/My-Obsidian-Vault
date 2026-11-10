# V115B: enable GPIOB and I2C peripheral clocks once, then verify SYSCTRL.
set ::v115b_status "INCOMPLETE_OR_UNKNOWN"
set ::v115b_halt_count 0
set ::v115b_target_write_count 0
proc v115b_dr {r} {set o [capture [format "riscv dmi_read 0x%X" $r]]; if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL reg=$r raw=<$o>"}; scan $x %x v; return [expr {$v&0xffffffff}]}
proc v115b_dw {r v label} {if {$r != 0x38 && $r != 0x39 && $r != 0x3C} {error "DMI_SETUP_WRITE_DENIED reg=$r"}; echo [format "V115B_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $r [expr {$v&0xffffffff}]]; riscv dmi_write [format "0x%X" $r] [format "0x%X" [expr {$v&0xffffffff}]]}
proc v115b_sb {label} {set s [v115b_dr 0x38]; echo [format "V115B_SBCS label=%s value=0x%08X" $label $s]; if {$s&0x00607000} {error "SBA_BUSY_OR_ERROR $label"}; return $s}
proc v115b_read {a label} {v115b_sb "${label}_PRE"; v115b_dw 0x38 0x20140404 "${label}_READ_MODE"; v115b_sb "${label}_MODE"; v115b_dw 0x39 $a "${label}_ADDRESS"; set v [v115b_dr 0x3C]; v115b_sb "${label}_DONE"; v115b_dw 0x38 0x20040404 "${label}_RETURN_IDLE"; v115b_sb "${label}_IDLE"; echo [format "V115B_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]; return $v}
proc v115b_triplet {a label expected} {set vals {}; foreach n {1 2 3} {if {$n>1} {sleep 10}; lappend vals [v115b_read $a "${label}_$n"]}; set x [lindex $vals 0];set y [lindex $vals 1];set z [lindex $vals 2]; echo [format "V115B_TRIPLET label=%s values=%08X,%08X,%08X" $label $x $y $z]; if {$x!=$y||$y!=$z||$x!=$expected} {error "TRIPLET_MISMATCH $label"};return $x}
proc v115b_write_once {a v label} {v115b_sb "${label}_PRE";v115b_dw 0x38 0x20040404 "${label}_WRITE_MODE";v115b_sb "${label}_MODE_IDLE";v115b_dw 0x39 $a "${label}_ADDRESS";v115b_sb "${label}_ADDRESS_IDLE";incr ::v115b_target_write_count;echo [format "V115B_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d" $a $v $::v115b_target_write_count];v115b_dw 0x3C $v "${label}_DATA";set done 0;for {set i 0} {$i<50} {incr i} {set s [v115b_dr 0x38];echo [format "V115B_WRITE_WAIT i=%d sbcs=0x%08X" $i $s];if {$s&0x00407000} {error "SBA_WRITE_ERROR"};if {($s&0x00200000)==0} {set done 1;break};sleep 1};if {!$done} {error "SBA_WRITE_TIMEOUT"};set got [v115b_read $a "${label}_READBACK"];if {$got!=$v} {error "WRITE_READBACK_MISMATCH expected=[format 0x%08X $v] got=[format 0x%08X $got]"};return $got}
set rc [catch {
 set init [capture {init}];echo "V115B_INIT_BEGIN";echo $init;echo "V115B_INIT_END"
 if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $init]} {error "OPENOCD_INIT_ERROR"}
 if {[jtag names] ne "riscv.cpu"||![regexp -nocase {0x1e200a6f} $init]} {error "TAP_IDCODE_MISMATCH"};if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $init]} {error "DAPLINK_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate];echo "V115B_CPU_INITIAL=$cpu";if {$cpu eq "running"} {capture {halt 2000};incr ::v115b_halt_count;set cpu [riscv.cpu curstate]};echo "V115B_CPU_FINAL=$cpu";if {$cpu ne "halted"||$::v115b_halt_count>1} {error "CPU_NOT_HALTED"}
 set dm [v115b_dr 0x11];echo [format "V115B_DMSTATUS=0x%08X" $dm];if {($dm&0x300)!=0x300||($dm&0xC00)!=0} {error "DMSTATUS_NOT_HALTED"};v115b_sb PREFLIGHT
 v115b_triplet 0x4002180C PERI_CLKEN 0
 v115b_triplet 0x40021810 PERI_RST 0
 v115b_write_once 0x4002180C 0x00000021 GPIOB_I2C_CLOCK_ENABLE
 v115b_triplet 0x4002180C PERI_CLKEN_POST 0x21
 v115b_triplet 0x40021810 PERI_RST_POST 0
 set ::v115b_status "PASS_CLOCKS_ENABLED"
} err]
if {$rc} {set ::v115b_status "FAIL_OR_UNKNOWN";echo "V115B_ERROR=$err"}
set sbrc [catch {v115b_sb FINAL} sbv];echo [format "V115B_FINAL_SBCS rc=%d value=%s" $sbrc $sbv];set dmrc [catch {v115b_dr 0x11} dmv];echo [format "V115B_FINAL_DMSTATUS rc=%d value=%s" $dmrc $dmv]
echo [format "V115B_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v115b_status $::v115b_halt_count $::v115b_target_write_count];echo "V115B_COMPLETE";shutdown
