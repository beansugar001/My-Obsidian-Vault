.section .text,"ax"
.globl _start
.option norvc
_start:
    li s0, 0x2000f000
    li t0, 0x53454231
    sw zero, 16(s0)
    sw t0, 0(s0)
    li t0, 0x13579bdf
    li t1, 0x2468ace0
    nop
    sw t0, 20(s0)
    nop
    nop
    lw s1, 20(s0)
    nop
    nop
    sw t1, 20(s0)
    nop
    nop
    lw s2, 20(s0)
    nop
    nop
    sw s1, 4(s0)
    sw s2, 8(s0)
    li t2, 0x5345fa11
    bne s1, t0, publish
    bne s2, t1, publish
    li t2, 0x5345600d
publish:
    nop
    nop
    sw t2, 16(s0)
done:
    j done
