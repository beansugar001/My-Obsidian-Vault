.section .text,"ax"
.globl _start
.option norvc
_start:
    lui s0, 0x2000f
    lui s1, 0x53454
    lui s4, 0x13579
    lui t0, 0x4c575
    li s6, 32
    sw zero, 44(s0)
    sw t0, 0(s0)
    sw s1, 28(s0)
    sw s4, 32(s0)
    sw s6, 36(s0)

    sw s4, 48(s0)
    addi s2, s0, 4
    li s5, 0
    li s7, 0
    jal s3, wait_iteration

    sw s4, 48(s0)
    addi s2, s0, 16
    li s5, 0
    li s7, 7
    nop
    sw s7, 40(s0)
    jal s3, wait_iteration

    lui t0, 0x4c576
    nop
    sw t0, 44(s0)
done:
    j done

    .org 0xf0
wait_iteration:
    addi s5, s5, 1
    lw t0, 48(s0)
    nop
    nop
shared_branch:
    bne t0, s1, no_match
    lui t1, 0x4d415
    j record
no_match:
    bgeu s5, s6, limit_reached
    bne s5, s7, wait_iteration
    sw s1, 48(s0)
    nop
    j wait_iteration
limit_reached:
    lui t1, 0x4c494
record:
    nop
    sw s5, 0(s2)
    sw t0, 4(s2)
    sw t1, 8(s2)
    jalr zero, 0(s3)
