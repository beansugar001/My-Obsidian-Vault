proc go {} {
    if {[catch {init} e]} { echo "AP_ERROR=$e"; return }
    if {[riscv.cpu curstate] eq "running"} { halt 2000 }
    # case A: equal operands, enter at xor
    reg t0 0x2468ACE0
    reg t1 0x13579BDF
    reg s7 0x2468ACE0
    reg s6 0x13579BDF
    reg ra 0x0000011c
    reg pc 0x00000178
    resume
    sleep 60
    halt 2000
    echo "AP_A_A0=[reg a0] PC=[reg pc]"
    # case B: differing operands, enter at xor
    reg t0 0x2468ACE1
    reg t1 0x13579BDF
    reg s7 0x2468ACE0
    reg s6 0x13579BDF
    reg ra 0x0000011c
    reg pc 0x00000178
    resume
    sleep 60
    halt 2000
    echo "AP_B_A0=[reg a0] PC=[reg pc]"
    # case C: xor only then stop at or
    reg t0 0x2468ACE0
    reg t1 0x13579BDF
    reg s7 0x2468ACE0
    reg s6 0x13579BDF
    reg pc 0x00000178
    resume
    sleep 60
    halt 2000
    echo "AP_C_A0=[reg a0] T0=[reg t0] T1=[reg t1] PC=[reg pc]"
    echo "AP_DONE"
}
if {[catch {go} e]} { echo "AP_TOP=$e" }
shutdown
