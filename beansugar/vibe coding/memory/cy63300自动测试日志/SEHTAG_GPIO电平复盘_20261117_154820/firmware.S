.section .text,"ax"
.globl _start
.option norvc
_start:
    lui s0, 0x40000
    addi s0, s0, 0x200
    lui a0, 0x40022
    lw a1, -2036(a0)
    ori a1, a1, 1
    nop
    sw a1, -2036(a0)
    nop
    nop

    lw a1, 4(s0)
    andi a1, a1, -4
    sw a1, 4(s0)
    lw a1, 0x68(s0)
    andi a1, a1, -64
    sw a1, 0x68(s0)
    lw a1, 0x6c(s0)
    andi a1, a1, -16
    sw a1, 0x6c(s0)
    lw a1, 0(s0)
    andi a1, a1, -4
    sw a1, 0(s0)
    lw a1, 0x58(s0)
    andi a1, a1, -196
    ori a1, a1, 3
    sw a1, 0x58(s0)
    lw a1, 0x5c(s0)
    andi a1, a1, -196
    ori a1, a1, 0x80
    sw a1, 0x5c(s0)

    lw a1, 4(s0)
    ori a1, a1, 1
    nop
    sw a1, 4(s0)
terminal:
    j terminal
