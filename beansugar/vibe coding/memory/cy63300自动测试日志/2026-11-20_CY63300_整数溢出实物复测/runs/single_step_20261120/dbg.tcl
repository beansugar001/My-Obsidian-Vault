proc go {} {
    init
    if {[riscv.cpu curstate] eq "running"} { halt 2000 }
    echo "DBG_STATE=[riscv.cpu curstate]"
    echo "DBG_CATCH_STEP=[catch {step} e] E=$e"
    echo "DBG_CATCH_STEP1=[catch {step 1} e2] E=$e2"
    echo "DBG_CATCH_REG=[catch {reg pc 0x000000c0} e3] E=$e3"
    echo "DBG_PC=[reg pc]"
    echo "DBG_A0=[reg a0]"
    echo "DBG_DONE"
}
if {[catch {go} e]} { echo "DBG_TOP=$e" }
shutdown
