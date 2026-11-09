# V109C: configure Pad8/9 as open-drain I2C AF3 while controller/FIFOs remain disabled.
set ::v109c_status "INCOMPLETE_OR_UNKNOWN"; set ::v109c_write_count 0; set ::v109c_halt_count 0
proc v109c_dread {reg} { set o [capture [format "riscv dmi_read 0x%X" $reg]]; if {![regexp -nocase {0x([0-9a-f]+)} $o -> x]} {error "DMI_READ_PARSE_FAIL $reg <$o>"}; scan $x %x v; return [expr {$v & 0xffffffff}] }
proc v109c_dwrite {reg value label} { echo [format "V109C_DMI_WRITE label=%s reg=0x%02X value=0x%08X" $label $reg [expr {$value & 0xffffffff}]]; riscv dmi_write [format "0x%X" $reg] [format "0x%X" [expr {$value & 0xffffffff}]] }
proc v109c_sb_ok {label} { set s [v109c_dread 0x38]; echo [format "V109C_SBCS label=%s value=0x%08X" $label $s]; if {$s & 0x00607000} {error "SBA_BUSY_OR_ERROR $label"}; return $s }
proc v109c_read {a label} { v109c_sb_ok "${label}_BEFORE"; v109c_dwrite 0x38 0x20140404 "${label}_READ_MODE"; v109c_sb_ok "${label}_MODE"; v109c_dwrite 0x39 $a "${label}_ADDRESS"; set v [v109c_dread 0x3c]; v109c_sb_ok "${label}_AFTER"; echo [format "V109C_MMIO_READ label=%s addr=0x%08X value=0x%08X" $label $a $v]; return $v }
proc v109c_write_verify {a v label} { v109c_sb_ok "${label}_PRE"; v109c_dwrite 0x38 0x20040404 "${label}_WRITE_MODE"; v109c_sb_ok "${label}_WRITE_MODE_IDLE"; v109c_dwrite 0x39 $a "${label}_ADDRESS"; v109c_sb_ok "${label}_ADDRESS_IDLE"; incr ::v109c_write_count; echo [format "V109C_TARGET_MMIO_WRITE_ATTEMPT addr=0x%08X value=0x%08X count=%d label=%s" $a $v $::v109c_write_count $label]; v109c_dwrite 0x3c $v "${label}_TARGET_WRITE"; set done 0; for {set i 0} {$i < 50} {incr i} {set s [v109c_dread 0x38]; echo [format "V109C_WRITE_POLL_%s_%02d=0x%08X" $label $i $s]; if {$s & 0x00407000} {error "SBA_WRITE_ERROR $label"}; if {($s & 0x00200000)==0} {set done 1; break}; sleep 1}; if {!$done} {error "SBA_WRITE_TIMEOUT $label"}; set got [v109c_read $a "${label}_VERIFY"]; if {$got != $v} {error "WRITE_READBACK_MISMATCH $label expected=[format 0x%08X $v] got=[format 0x%08X $got]"}; return $got }
set rc [catch {
 set il [capture {init}]; echo "V109C_INIT_BEGIN"; echo $il; echo "V109C_INIT_END"
 if {[regexp -nocase {Error:|scan chain interrogation failed|IR capture error|dtmcontrol is 0|unable to find CMSIS-DAP} $il]} {error "OPENOCD_INIT_ERROR"}
 if {[jtag names] ne "riscv.cpu" || ![regexp -nocase {0x1e200a6f} $il]} {error "TAP_OR_IDCODE_MISMATCH"}; if {![regexp -- {07000001006700343500000a4e57354aa5a5a5a597969908} $il]} {error "PROBE_SERIAL_MISMATCH"}
 set cpu [riscv.cpu curstate]; echo "V109C_CPU_INITIAL=$cpu"; if {$cpu eq "running"} {set h [capture {halt 2000}]; incr ::v109c_halt_count; echo "V109C_HALT=$h"; set cpu [riscv.cpu curstate]}; echo "V109C_CPU_FINAL=$cpu"; if {$cpu ne "halted" || $::v109c_halt_count>1} {error "HALT_FAILED"}
 set dm [v109c_dread 0x11]; echo [format "V109C_DMSTATUS=0x%08X" $dm]; if {($dm & 0x300)!=0x300 || ($dm & 0xc00)!=0} {error "DMSTATUS_NOT_HALTED"}; v109c_sb_ok PREFLIGHT
 foreach {label addr expected} {PERI_CLKEN 0x4002180C 0x21 PERI_RST 0x40021810 0 GPIOB_ODR 0x40000100 0 GPIOB_DIR 0x40000104 0 GPIOB_OSOD 0x40000158 0 GPIOB_AFR1 0x40000168 0 MODULE_CTRL 0x40002800 2 FIFO_STA 0x4000280C 5 I2C_STATUS 0x4000283C 0} {set got [v109c_read $addr $label]; if {$got!=$expected} {error "PRECONDITION_MISMATCH $label expected=[format 0x%08X $expected] got=[format 0x%08X $got]"}}
 set idr [v109c_read 0x40000150 GPIOB_IDR_PRE]; echo [format "V109C_GPIOB_IDR_PRE=0x%08X PB2_PAD8=%d PB3_PAD9=%d" $idr [expr {($idr>>2)&1}] [expr {($idr>>3)&1}]]
 # ODR=1 for PB2/3 first, while still inputs; then open-drain; then output-enable (released); AF3 last.
 v109c_write_verify 0x40000100 0x0000000C GPIOB_ODR_RELEASE
 v109c_write_verify 0x40000158 0x0000000C GPIOB_OPEN_DRAIN
 v109c_write_verify 0x40000104 0x0000000C GPIOB_DIR_OUTPUT_RELEASED
 v109c_write_verify 0x40000168 0x000006C0 GPIOB_PAD8_PAD9_I2C_AF3
 set idr2 [v109c_read 0x40000150 GPIOB_IDR_POST]; echo [format "V109C_GPIOB_IDR_POST=0x%08X PB2_PAD8=%d PB3_PAD9=%d" $idr2 [expr {($idr2>>2)&1}] [expr {($idr2>>3)&1}]]
 set module [v109c_read 0x40002800 MODULE_CTRL_POST]; if {$module & 0xD} {error "CONTROLLER_OR_FIFO_ENABLE_NOT_ZERO"}
 if {($idr2&0xC)!=0xC} {set ::v109c_status "STOP_LINES_NOT_SAMPLED_HIGH"} else {set ::v109c_status "PASS_PAD8_PAD9_AF3_RELEASED"}
} err]
if {$rc} {set ::v109c_status "FAIL_OR_UNKNOWN"; echo "V109C_ERROR=$err"}
set sf [catch {v109c_sb_ok FINAL} sv]; echo [format "V109C_FINAL_SBCS rc=%d value=%s" $sf $sv]; set df [catch {v109c_dread 0x11} dv]; echo [format "V109C_FINAL_DMSTATUS rc=%d value=%s" $df $dv]
echo [format "V109C_RESULT=%s HALT_COUNT=%d TARGET_MMIO_WRITE_COUNT=%d" $::v109c_status $::v109c_halt_count $::v109c_write_count]; echo "V109C_COMPLETE"; shutdown