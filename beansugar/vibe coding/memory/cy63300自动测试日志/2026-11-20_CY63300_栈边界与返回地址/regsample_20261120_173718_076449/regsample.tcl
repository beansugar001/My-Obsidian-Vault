proc reg1 {name} {
    if {[catch {reg $name} v]} { return "ERR:$v" }
    return [string trim $v]
}
proc sample {i} {
    echo [format "RS %s pc=%s sp=%s ra=%s gp=%s tp=%s" $i [reg1 pc] [reg1 sp] [reg1 ra] [reg1 gp] [reg1 tp]]
}
proc go {} {
    if {[catch {init} e]} { echo "RS_ERROR=init:$e"; return }
    echo "RS_CURSTATE0=[riscv.cpu curstate]"
    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }
    echo "RS_CURSTATE1=[riscv.cpu curstate]"
    sample 1
    after 300
    sample 2
    if {[catch {resume}]} { echo "RS_RESUME_FAIL" }
    after 500
    if {[catch {halt 2000}]} { echo "RS_HALT2_FAIL" }
    sample 3
    if {[catch {resume}]} { echo "RS_RESUME2_FAIL" }
    echo "RS_DONE"
}
if {[catch {go} r]} { echo "RS_TOP_ERROR=$r" }
shutdown
