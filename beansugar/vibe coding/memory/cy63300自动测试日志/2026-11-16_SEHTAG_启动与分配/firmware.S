.section .text,"ax"
.globl _start
_start:
    csrr s0, 0x803
    nop
    nop
    bnez s0, fail
    csrwi 0x803, 1
    nop
    nop
    csrr s1, 0x803
    nop
    nop
    li t0, 1
    nop
    nop
    bne s1, t0, fail
    li s10, 0x60
1:  j 1b
fail:
    li s10, 0x3f
2:  j 2b
