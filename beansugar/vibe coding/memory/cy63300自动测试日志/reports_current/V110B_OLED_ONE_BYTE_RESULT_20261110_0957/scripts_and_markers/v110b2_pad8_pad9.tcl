# V110B2: configure Pad8/9 as open-drain I2C AF3 while controller/FIFOs remain disabled.
set ::v110b2_status "INCOMPLETE_OR_UNKNOWN"; set ::v110b2_write_count 0; set ::v110b2_halt_count 0
proc v110b2_dread {reg} { set o [capture [format "riscv dmi_read 0x%X" $reg]]; if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $reg <$o>"}; scan $x %x v; return [expr {$v & 0xffffffff}] }
proc v110b2_dwrite {reg value label} { echo [format "V110B2_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]; riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]] }
proc v110b2_sb_ok {label} { set s [v110b2_dread 0x38]; echo [format "V110B2_SBCS label=%s value=0x%08X" $label $s]; if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR $label"}; return $s }
proc v110b2_read {a label} { v110b2_sb_ok "${label}_BEFORE"; v110b2_dwrite 0x38 0x20140404 "${label}_READ_MODE"; v110b2_sb_ok "${label}_MODE"; v110b2_dwrite 0x39 $a "${label}_ADDRESS"; set v [v110b2_dread 0x3c]; v110b2_sb_ok "${label}_AFTER"; echo [format "V110B2_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]; return $v }
proc v110b2_write_verify {a v label} { v110b2_sb_ok "${label}_PRE"; v110b2_dwrite 0x38 0x20040404 "${label}_WRITE_MODE"; v110b2_sb_ok "${label}_WRITE_MODE_IDLE"; v110b2_dwrite 0x39 $a "${label}_ADDRESS"; v110b2_sb_ok "${label}_ADDRESS_IDLE"; incr ::v110b2_write_count; echo [format "V110B2_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v110b2_write_count $label]; v110b2_dwrite 0x3c $v "${label}_TARGET_WRITE"; set done 0; for {set i 0} {$i < 50} {incr i} {set s [v110b2_dread 0x38]; echo [format "V110B2_WRITE_POLL_%s_%02d=0x%08X" $label $i $s]; if {$s & 0x00407000} {error "SBA_WRITE_ERROR $label"}; if {($s & 0x00200000)==0} {set done 1; break}; sleep 1}; if {!$done} {error "SBA_WRITE_TIMEOUT $label"}; set got [v110b2_read $a "${label}_VERIFY"]; if {$got != $v} {error "WRITE_READBACK_MISMATCH $label expected=[format 0x%08X $v] got=[format 0x%08X $got]"}; return $got }
set rc [catch {
 set il [capture {init}]; echo "V110B2_INIT_BEGIN"; echo $il; echo "V110B2_INIT_END"
 if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} {error "OPENOCD_INIT_ERROR"}
 if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} {error "TAP_OR_IDCODE_MISMATCH"}; if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} {error "PROBE_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate]; echo "V110B2_CPU_INITIAL=$cpu"; if {$cpu eq "running"} {set h [capture {halt 2000}]; incr ::v110b2_halt_count; echo "V110B2_HALT=$h"; set cpu [riscv.cpu curstate]}; echo "V110B2_CPU_FINAL=$cpu"; if {$cpu ne "halted" || $::v110b2_halt_count>1} {error "HALT_FAILED"}
 set dm [v110b2_dread 0x11]; echo [format "V110B2_DMSTATUS=0x%08X" $dm]; if {($dm & 0x300)!=0x300 || ($dm & 0xc00)!=0} {error "DMSTATUS_NOT_HALTED"}; v110b2_sb_ok PREFLIGHT
 foreach {label addr expected} {PERI_CLKEN 0x4002180C 0x21 PERI_RST 0x40021810 0 GPIOB_ODR 0x40000100 0 GPIOB_DIR 0x40000104 0 GPIOB_OSOD 0x40000158 0 GPIOB_AFR1 0x40000168 0 MODULE_CTRL 0x40002800 2 FIFO_STA 0x4000280C 5 I2C_STATUS 0x4000283C 0} {set got [v110b2_read $addr $label]; if {$got!=$expected} {error "PRECONDITION_MISMATCH $label expected=[format 0x%08X $expected] got=[format 0x%08X $got]"}}
 set idr [v110b2_read 0x40000150 GPIOB_IDR_PRE]; echo [format "V110B2_GPIOB_IDR_PRE=0x%08X PB2_PAD8=%d PB3_PAD9=%d" $idr [expr {($idr>>2)&1}] [expr {($idr>>3)&1}]]
 # ODR=1 for PB2/3 first, while still inputs; then open-drain; then output-enable (released); AF3 last.
 v110b2_write_verify 0x40000100 0x0000000C GPIOB_ODR_RELEASE
 v110b2_write_verify 0x40000158 0x0000000C GPIOB_OPEN_DRAIN
 v110b2_write_verify 0x40000104 0x0000000C GPIOB_DIR_OUTPUT_RELEASED
 v110b2_write_verify 0x40000168 0x000006C0 GPIOB_PAD8_PAD9_I2C_AF3
 set idr2 [v110b2_read 0x40000150 GPIOB_IDR_POST]; echo [format "V110B2_GPIOB_IDR_POST=0x%08X PB2_PAD8=%d PB3_PAD9=%d" $idr2 [expr {($idr2>>2)&1}] [expr {($idr2>>3)&1}]]
 set module [v110b2_read 0x40002800 MODULE_CTRL_POST]; if {$module & 0xD} {error "CONTROLLER_OR_FIFO_ENABLE_NOT_ZERO"}
 if {($idr2&0xC)!=0xC} {set ::v110b2_status "STOP_LINES_NOT_SAMPLED_HIGH"} else {set ::v110b2_status "PASS_PAD8_PAD9_AF3_RELEASED"}
} err]
if {$rc} {set ::v110b2_status "FAIL_OR_UNKNOWN"; echo "V110B2_ERROR=$err"}
set sf [catch {v110b2_sb_ok FINAL} sv]; echo [format "V110B2_FINAL_SBCS rc=%d value=%s" $sf $sv]; set df [catch {v110b2_dread 0x11} dv]; echo [format "V110B2_FINAL_DMSTATUS rc=%d value=%s" $df $dv]
echo [format "V110B2_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v110b2_status $::v110b2_halt_count $::v110b2_write_count]; echo "V110B2_COMPLETE"; shutdown