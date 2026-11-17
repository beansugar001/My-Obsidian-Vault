.section .text,"ax"
.globl _start
.option norvc
.equ mailbox_base, 0x2000f000
.equ trigger_code, 0x53454152
_start:
    li s0, mailbox_base
    li s4, trigger_code
    sw zero, 0(s0)
    sw zero, 20(s0)
    sw zero, 16(s0)
    li t0, 0x53454833
    nop
    sw t0, 0(s0)
wait_for_trigger:
    lw t0, 20(s0)
    nop
    nop
    bne t0, s4, wait_for_trigger
    sw zero, 20(s0)
    li t0, 0x53450001
    nop
    sw t0, 16(s0)

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

    sw s1, 4(s0)
    sw s2, 8(s0)
    sw s3, 12(s0)
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
