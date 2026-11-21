# CY63300 registration probe v4: the SAME out-of-object store, two successors
# Repo 189fff5 reference RTL.  Stack object id1 [sp, sp+31] on sp; mailbox object
# id0 [0x2000F100,0x2000F17F] on s10; both via WRPLM + 2x LDBNB + WRTAG.
#
# T1: OOB store 0x2001FF08, successor rs1 = x0   -> expected bypass (commits)
# T2: OOB store 0x2001FF0C, successor rs1 = sp   -> expected checked/rejected
.section .text,"ax"
.globl _start
.option norvc
.option norelax

_start:
    lui  s0, 0x2000f
    sw   zero, 0(s0)
    la   t0, trap_entry
    csrw mtvec, t0
    li   sp, 0x2001ff00
    li   s10, 0x2000f100
    sw   sp, 4(s0)
    addi sp, sp, -32
    sw   sp, 8(s0)

    li   t2, 0
    mv   t3, s10
    li   t4, 0x2000f17f
    .word 0x01c3807b
    .word 0x41d3807b
    .word 0x00038d6b
    .word 0x40038d6b
    .word 0x001d0d5b

    li   t2, 1
    mv   t3, sp
    addi t4, sp, 31
    .word 0x01c3807b
    .word 0x41d3807b
    .word 0x0003816b
    .word 0x4003816b
    .word 0x0011015b

    li   t0, 0x4d533150
    sw   t0, 48(s10)            # r12
    addi x0, x0, 0

    li   t0, 0xa5a5a5a5
    li   t1, 0x2001ff08
    sw   t0, 0(t1)
    sw   t0, 4(t1)              # poison 0x2001FF08 and 0x2001FF0C
    addi x0, x0, 0

    li   t0, 1
    csrw 0x803, t0

    # ---- T1: successor has rs1 = x0
    li   t0, 0xcafe1111
    sw   t0, 40(sp)             # 0x2001FF08
    addi x0, x0, 0
    li   t0, 0x4d5331b1
    sw   t0, 52(s10)            # r13
    addi x0, x0, 0

    # ---- T2: same kind of store, successor has rs1 = sp
    li   t0, 0xcafe3333
    sw   t0, 44(sp)             # 0x2001FF0C
    lw   t1, 0(sp)              # successor: rs1 = sp (stack object)
    li   t0, 0x4d5331b4
    sw   t0, 60(s10)            # r15
    addi x0, x0, 0

    li   t0, 0x4d533155
    sw   t0, 28(s10)            # r7 no-trap marker
nospin:
    j    nospin

.balign 4
trap_entry:
    csrw 0x803, zero
    csrr t1, mcause
    csrr t2, mepc
    sw   t1, 8(s10)
    sw   t2, 12(s10)
    li   t3, 0x4d533142
    sw   t3, 16(s10)
    li   t4, 0x2001ff08
    lw   t5, 0(t4)
    sw   t5, 20(s10)            # r5 = 0x2001FF08
    lw   t5, 4(t4)
    sw   t5, 24(s10)            # r6 = 0x2001FF0C
    li   t4, 0x70000000
    lw   t5, 0(t4)
    sw   t5, 32(s10)
    lw   t5, 4(t4)
    sw   t5, 36(s10)
    lw   t5, 8(t4)
    sw   t5, 40(s10)
    lw   t5, 12(t4)
    sw   t5, 44(s10)
tspin:
    j    tspin
