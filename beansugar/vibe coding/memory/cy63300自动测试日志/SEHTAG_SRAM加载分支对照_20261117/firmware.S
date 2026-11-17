.section .text,"ax"
.globl _start
.option norvc
_start:
    lui s0, 0x2000f
    lui s1, 0x53454
    lui s4, 0x13579
    lui s5, 0x4c425
    sw zero, 36(s0)
    sw s4, 48(s0)
    sw s5, 0(s0)
    sw s1, 28(s0)
    sw s4, 32(s0)

    addi s2, s0, 4
    jal s3, register_case
    addi s2, s0, 12
    jal s3, short_load_case
    addi s2, s0, 20
    jal s3, paced_load_case
    lui t0, 0x4c426
    nop
    sw t0, 36(s0)
done:
    j done

    .org 0xc0
register_case:
    add t0, s4, zero
    j join_branch

    .org 0xd0
paced_load_case:
    lw t0, 48(s0)
    nop
    nop
    nop
    nop
    nop
    j join_branch

    .org 0xf4
short_load_case:
    lw t0, 48(s0)
join_branch:
    nop
    nop
shared_branch:
    bne t0, s1, taken
    lui t1, 0x4e4f0
    j record
taken:
    lui t1, 0x54414
record:
    nop
    sw t0, 0(s2)
    sw t1, 4(s2)
    jalr zero, 0(s3)
