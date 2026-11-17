.section .text,"ax"
.globl _start
.option norvc
_start:
    li s0, 0x2000f000
    la t0, trap_entry
    nop
    nop
    csrw mtvec, t0
    nop
    nop
    csrr s1, 0x803
    nop
    nop
    bnez s1, unexpected_state
    sw zero, 16(s0)

    csrwi 0x803, 1
    nop
    nop
    csrr s2, 0x803
    nop
    nop
    csrw 0x803, s1
    nop
    nop
    csrr s3, 0x803
    nop
    nop
    bnez s3, unexpected_state

    li t0, 0x53454832
    sw s1, 4(s0)
    sw s2, 8(s0)
    sw s3, 12(s0)
    sw t0, 0(s0)
    li t1, 1
    li t0, 0x5345fa11
    bne s2, t1, publish
    li t0, 0x5345600d
publish:
    nop
    nop
    sw t0, 16(s0)
done:
    j done

.balign 4
trap_entry:
    li s10, 0x3f
    j done
unexpected_state:
    li s10, 0x3e
    j done
