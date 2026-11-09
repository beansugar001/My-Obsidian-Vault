
set cy_init_log [capture {init}]
echo $cy_init_log
if {[regexp -nocase {(Error|Warn)\s*:} $cy_init_log]} {error "CY_INIT_ERROR_STOP"}
set cy_ids [regexp -all -inline -nocase {tap/device found:\s*(0x[0-9a-f]+)} $cy_init_log]
if {[llength $cy_ids] != 2 || [string tolower [lindex $cy_ids 1]] ne "0x1e200a6f"} {error "CY_ID_STOP"}
set cy_misas [regexp -all -inline -nocase {misa=(0x[0-9a-f]+)} $cy_init_log]
if {[llength $cy_misas] != 2} {error "CY_MISA_MISSING_STOP"}
set cy_misa [expr {[lindex $cy_misas 1] & 0xffffffff}]
if {$cy_misa == 0 || $cy_misa == 0xffffffff} {error "CY_MISA_ABNORMAL_STOP"}
set cy_halt_log [capture {halt}]
echo $cy_halt_log
if {[regexp -nocase {(Error|Warn)\s*:} $cy_halt_log]} {error "CY_HALT_ERROR_STOP"}
