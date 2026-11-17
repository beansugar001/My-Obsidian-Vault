.section .text,"ax"
.globl _start
.option norvc
_start:
    .rept 280
    nop
    .endr
    li t0, 0x600
    csrw mtvec, t0
    nop
    nop
    li a1, 32
    li s2, 0x1234abcd
    csrwi 0x803, 1
    nop
    nop
    # Local simulation ABI. Verify the generated word independently.
    .word ((8 << 20) | (11 << 15) | (1 << 12) | (10 << 7) | 0x0b)
    nop
    nop
    sw s2, 0(a0)
    nop
    nop
    lw s3, 0(a0)
    nop
    nop
    bne s3, s2, fail
    li s10, 0x60
1:  j 1b
fail:
    li s10, 0x3f
2:  j 2b

.org 0x600
trap_entry:
    csrr s2, mcause
    nop
    nop
    li s10, 0x61
3:  j 3b
