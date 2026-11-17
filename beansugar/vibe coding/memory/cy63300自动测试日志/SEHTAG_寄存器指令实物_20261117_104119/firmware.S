.section .text,"ax"
.globl _start
.option norvc
_start:
    lui s0, 0x2000f
    lui s1, 0x57416
    sw zero, 36(s0)
    sw s1, 0(s0)
    sw s1, 8(s0)

    addi s2, s1, 13
    nop
    sw s2, 4(s0)
    sw s1, 12(s0)
    addi s1, s1, 29
    nop
    nop
    sw s1, 16(s0)

    lui s3, 0x13579
    lui s4, 0x2468a
    nop
    beq s3, s4, equal_wrong
    lui s5, 0x11111
    j store_equal
equal_wrong:
    lui s5, 0xeeee1
store_equal:
    nop
    sw s5, 20(s0)

    bne s3, s4, unequal_ok
    lui s6, 0xeeee2
    j store_unequal
unequal_ok:
    lui s6, 0x22222
store_unequal:
    nop
    sw s6, 24(s0)
    j matched_sequence

    # Use the addresses from the original abnormal status sequence.
    .org 0x90
matched_sequence:
    bne s5, s5, store_matched
    lui t1, 0x57416
    addi t1, t1, 13
store_matched:
    nop
    nop
    sw t1, 28(s0)

    lui t0, 0x2d5a7
    nop
    sw t0, 32(s0)
    lui t0, 0x53457
    nop
    sw t0, 36(s0)
done:
    j done
