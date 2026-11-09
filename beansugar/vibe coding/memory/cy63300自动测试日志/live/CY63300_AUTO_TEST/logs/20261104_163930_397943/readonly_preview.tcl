
proc dr {r} {
 set raw [capture "riscv dmi_read $r"]
 if {![regexp {^\s*(0x[0-9a-fA-F]+)\s*$} $raw -> value]} {error "CY_DMI_PARSE"}
 return [expr {$value & 0xffffffff}]
}
proc idle {} {
 set s [dr 0x38]
 if {($s & 0x00607000) != 0} {error "CY_SBA_BUSY_OR_ERROR"}
 if {(($s >> 29) & 7) != 1 || (($s >> 5) & 127) != 32 || ($s & 4) == 0} {error "CY_UNKNOWN_SBA"}
 return $s
}
proc mode {v} {
 idle
 riscv dmi_write 0x38 $v
 set s [idle]
 if {$s != $v} {error "CY_MODE_MISMATCH"}
}
proc rd {a} {
 if {[lsearch -exact {0x4002180C 0x40021810 0x40002800 0x4000280C 0x40002810 0x40002814} $a] < 0} {error "CY_READ_NOT_ALLOWED"}
 mode 0x20140404
 riscv dmi_write 0x39 $a
 idle
 set v [dr 0x3c]
 idle
 mode 0x20040404
 return $v
}
set dm [dr 0x11]
echo [format "CY_DMSTATUS 0x%08X" $dm]
if {$dm != 0x00430382} {error "CY_DMSTATUS_UNKNOWN"}
set initial [idle]
if {$initial != 0x20040404} {error "CY_INITIAL_SBA_UNKNOWN"}
for {set i 1} {$i <= 3} {incr i} {
 foreach {a expected} {0x4002180C 0x20 0x40021810 0 0x40002800 2 0x4000280C 5 0x40002810 0x20 0x40002814 0x30} {
  set v [rd $a]
  echo [format "CY_SAMPLE %d %s 0x%08X" $i $a $v]
  if {$v != $expected} {error "CY_BASELINE_MISMATCH_STOP"}
 }
 if {$i < 3} {sleep 100}
}
set dm [dr 0x11]
if {$dm != 0x00430382} {error "CY_DMSTATUS_CHANGED"}
idle
echo "CY_READONLY_COMPLETE"
