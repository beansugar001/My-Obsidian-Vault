# CY63300 stack-object diagnostic v2b (NOT flashed yet).
# Question: after csrw 0x803,1, does the core hang, trap, or continue?
# M1 0x2000F110 = 0x4D533144  enable->disable pair executed, store after disable landed
# M2 0x2000F114 = 0x4D533145  core got PAST the untagged stack store (no trap)
# M3 0x2000F118 = 0x4D533146  trap handler entered and cleared safety
# r7 0x2000F11C = 0x4D533142  trap marker (handler reached its dumps)
# r11 0x2000F12C = 0x4D533143 no-trap marker
.section .text,"ax"
.globl _start
.option norvc
.option norelax

_start:
    lui  s0, 0x2000f
    li   s1, 0x2000f040
    sw   zero, 0(s0)
    la   t0, trap_entry
    csrw mtvec, t0
    li   sp, 0x2001ff00
    li   s10, 0x2000f100
    sw   sp, 4(s0)
    addi sp, sp, -32
    sw   sp, 8(s0)

    li   t0, 0x11112222
    li   t1, 0x33334444
    sw   t0, 0(sp)
    sw   t1, 4(sp)
    lw   t2, 0(sp)
    lw   t3, 4(sp)
    sw   t2, 12(s0)
    sw   t3, 16(s0)

    li   t0, 0x13579bdf
    li   t1, 0x2468ace0
    sw   t0, 0(s1)
    sw   t1, 4(s1)

    li   a0, 2
    jal  ra, stack_copy
    sw   a0, 20(s0)
    lw   t0, 16(sp)
    lw   t1, 20(sp)
    sw   t0, 24(s0)
    sw   t1, 28(s0)

    li   a0, 3
    jal  ra, stack_copy
    sw   a0, 40(s0)
    lw   t0, 16(sp)
    lw   t1, 20(sp)
    sw   t0, 44(s0)
    sw   t1, 48(s0)

    li   a0, 0x40000001
    jal  ra, stack_copy
    sw   a0, 52(s0)
    lw   t0, 16(sp)
    lw   t1, 20(sp)
    sw   t0, 56(s0)
    sw   t1, 60(s0)

    li   t5, 0
    jal  ra, framer
after_call:
    la   t0, after_call
    lw   t1, 28(sp)
    xor  t2, t0, t1
    seqz t2, t2
    sw   t2, 0(s10)
    sw   t5, 4(s10)

    li   t0, 0x4d533141
    sw   t0, 0(s0)

    li   t0, 1
    csrw 0x803, t0
    csrw 0x803, zero
    li   t0, 0x4d533144
    sw   t0, 16(s10)          # M1

    li   t0, 1
    csrw 0x803, t0
    li   t1, 0x5555aaaa
    sw   t1, 8(sp)            # the untagged stack store under test
    csrw 0x803, zero
    li   t0, 0x4d533145
    sw   t0, 20(s10)          # M2
    li   t0, 0x4d533143
    sw   t0, 44(s10)          # no-trap marker
phase2_stop:
    j    phase2_stop

stack_copy:
    li   t0, 2
    bltu t0, a0, sc_reject
    slli t0, a0, 2
    mv   t1, s1
    addi t2, sp, 16
    add  t0, t2, t0
sc_loop:
    beq  t2, t0, sc_done
    lw   t3, 0(t1)
    nop
    sw   t3, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    j    sc_loop
sc_done:
    li   a0, 0
    ret
sc_reject:
    li   a0, 1
    ret

framer:
    sw   ra, 28(sp)
    jal  ra, leaf
    lw   ra, 28(sp)
    ret

leaf:
    addi t5, t5, 1
    ret

.balign 4
trap_entry:
    csrw 0x803, zero
    li   t4, 0x4d533146
    sw   t4, 24(s10)          # M3
    csrr t1, mcause
    csrr t2, mepc
    sw   t1, 8(s10)
    sw   t2, 12(s10)
    lw   t3, 8(sp)
    sw   t3, 32(s10)
    li   t4, 0x4d533142
    sw   t4, 28(s10)
tj_stop:
    j    tj_stop
