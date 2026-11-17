.section .text,"ax"
.globl _start
.option norvc
_start:
    li s0, 0x2000f000
    li s4, 0x53454152
    sw zero, 0(s0)
    sw zero, 20(s0)
    sw zero, 16(s0)
    li t0, 0x57414931
    nop
    sw t0, 0(s0)
first_load:
    lw t0, 20(s0)
    nop
    nop
    bne t0, s4, first_wait

    sw t0, 4(s0)
    sw s4, 8(s0)
    li s3, 1
    j publish_exit

first_wait:
    sw t0, 4(s0)
    sw s4, 8(s0)
    li t1, 0x57410001
    nop
    sw t1, 16(s0)
wait_repeat:
    lw t0, 20(s0)
    nop
    nop
    bne t0, s4, wait_repeat
    li s3, 2

publish_exit:
    xor s2, t0, s4
    sw t0, 12(s0)
    sw s3, 24(s0)
    sw s2, 28(s0)
    sw zero, 20(s0)
    li t1, 0x5741fa11
    bnez s2, write_status
    li t1, 0x5741600d
write_status:
    nop
    nop
    sw t1, 16(s0)
done:
    j done
