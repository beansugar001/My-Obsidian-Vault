.section .text,"ax"
.globl _start
.option norvc
_start:
    j init_gpio
startup_body:
    lui s1, 0x53454
    lui s4, 0x13579
    lui t0, 0x52544
    li s6, 32
    li s7, 7
    sw zero, 28(s0)
    sw zero, 32(s0)
    sw zero, 36(s0)
    sw zero, 40(s0)
    sw zero, 44(s0)
    sw t0, 0(s0)

    sw s4, 48(s0)
    addi s2, s0, 4
    addi s9, s0, 28
    li s5, 0
    li s8, 0
    jal s3, wait_iteration
after_direct:
    lui t0, 0x52546
    nop
    sw t0, 32(s0)

    sw s4, 48(s0)
    addi s2, s0, 16
    addi s9, s0, 36
    li s5, 0
    li s8, 1
    jal s3, wait_iteration
after_indirect:
    lui t0, 0x52546
    nop
    sw t0, 40(s0)
    lui t0, 0x52547
    nop
    sw t0, 44(s0)
done:
    j mark_done

gpio_config:
    # Release both pins before selecting GPIO mode.
    lw a1, 4(s10)
    andi a1, a1, -4
    sw a1, 4(s10)

    lw a1, 0x68(s10)
    andi a1, a1, -64
    sw a1, 0x68(s10)
    lw a1, 0x6c(s10)
    andi a1, a1, -16
    sw a1, 0x6c(s10)

    # Both output latches stay low. DIR selects release or sink.
    lw a1, 0(s10)
    andi a1, a1, -4
    sw a1, 0(s10)
    lw a1, 0x58(s10)
    andi a1, a1, -196
    ori a1, a1, 3
    sw a1, 0x58(s10)
    lw a1, 0x5c(s10)
    andi a1, a1, -196
    ori a1, a1, 0xc0
    sw a1, 0x5c(s10)
    li s11, 0
    j startup_body

    .org 0xf0
wait_iteration:
    addi s5, s5, 1
    lw t0, 48(s0)
    nop
    nop
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
    sw s5, 256(s2)
    sw s5, 0(s2)
    sw t0, 4(s2)
    sw t1, 8(s2)
    lui t2, 0x52545
    j mark_record
record_tail:
    sw t2, 0(s9)
    bnez s8, indirect_return
    j after_direct

    .org 0x170
indirect_return:
    jal zero, after_indirect

init_gpio:
    lui s0, 0x2000f
    lui s10, 0x40000
    addi s10, s10, 0x200
    lui a0, 0x40022
    lw a1, -2036(a0)
    ori a1, a1, 1
    nop
    sw a1, -2036(a0)
    nop
    nop
    j gpio_config

    .org 0x1c8
mark_done:
    li s11, 1
    lw a1, 4(s10)
    ori a1, a1, 1
    sw a1, 4(s10)
terminal:
    j terminal

mark_record:
    beqz s11, record_tail
    lw a1, 4(s10)
    ori a1, a1, 2
    sw a1, 4(s10)
    j record_tail
