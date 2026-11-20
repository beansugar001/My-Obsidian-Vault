.section .text,"ax"
.globl _start
.option norvc
.option norelax

_start:
    lui s0, 0x2000f
    addi s1, s0, 64
    sw zero, 0(s0)
    la t0, trap_entry
    csrw mtvec, t0
#ifdef BEFORE_RESTORE
    j setup_gpio
test_start:
#endif

    # The first two scratch words are the source, the next two the destination.
    lw s2, 0(s1)
    lw s3, 4(s1)
    lw s4, 8(s1)
    lw s5, 12(s1)
    sw s2, 48(s0)
    sw s3, 52(s0)
    sw s4, 56(s0)
    sw s5, 60(s0)
    li s6, 0x13579bdf
    li s7, 0x2468ace0
    sw s6, 0(s1)
    sw s7, 4(s1)
    sw zero, 8(s1)
    sw zero, 12(s1)

    li a0, 2
    jal ra, checked_copy
    sw a0, 4(s0)
    lw t0, 8(s1)
    lw t1, 12(s1)
    sw t0, 8(s0)
    sw t1, 12(s0)

    # Use different destination values to make an accidental copy observable.
    sw s7, 8(s1)
    sw s6, 12(s1)
#ifdef READ_RAW
    nop
    lw t0, 8(s1)
    lw t1, 12(s1)
    nop
    sw t0, 80(s0)
    sw t1, 84(s0)
    addi a1, s0, 88
#endif
    li a0, 3
    jal ra, checked_copy
    sw a0, 16(s0)
    jal ra, destination_equal
    sw a0, 20(s0)

#ifdef BEFORE_RESTORE
#ifdef LIVE_CHECK
    sw zero, 28(s0)
    li t0, 0x4d533134
#else
    li t0, 0x4d533133
#endif
    sw t0, 0(s0)
    lw a1, 4(s10)
    andi a1, a1, -4
    ori a1, a1, 1
    sw a1, 4(s10)
#else
    # The size calculation must reject this count before shifting.
#ifdef READ_RAW
    addi a1, s0, 96
#endif
    li a0, 0x40000001
    jal ra, checked_copy
    sw a0, 24(s0)
    jal ra, destination_equal
    sw a0, 28(s0)

    # Model a reused buffer, initialize it, and check subsequent usability.
    sw s6, 8(s1)
    sw s7, 12(s1)
    sw zero, 8(s1)
    sw zero, 12(s1)
    lw t0, 8(s1)
    lw t1, 12(s1)
    sw t0, 32(s0)
    sw t1, 36(s0)
    sw s7, 8(s1)
    sw s6, 12(s1)
    lw t0, 8(s1)
    lw t1, 12(s1)
    sw t0, 40(s0)
    sw t1, 44(s0)

    sw s2, 0(s1)
    sw s3, 4(s1)
    sw s4, 8(s1)
    sw s5, 12(s1)
#ifdef READ_RAW
    li t0, 0x4d533132
#else
    li t0, 0x4d533131
#endif
    sw t0, 0(s0)
#endif
terminal:
#ifdef LIVE_CHECK
    lw t1, 8(s1)
    nop
    beq t1, s7, terminal
    sw t1, 28(s0)
    lw a1, 4(s10)
    ori a1, a1, 2
    sw a1, 4(s10)
stopped:
    j stopped
#else
    j terminal
#endif

checked_copy:
    # Two four-byte elements fit both buffers. Check the count before
    # converting to bytes, so the size conversion cannot wrap.
    li t0, 2
    bltu t0, a0, reject_count
    slli t0, a0, 2
    mv t1, s1
    addi t2, s1, 8
    add t0, t2, t0
copy_word:
    beq t2, t0, copy_done
    lw t3, 0(t1)
    nop
    sw t3, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    j copy_word
copy_done:
    li a0, 0
    ret
reject_count:
    li a0, 1
    ret

destination_equal:
    lw t0, 8(s1)
    lw t1, 12(s1)
    nop
#ifdef READ_RAW
    sw t0, 0(a1)
    sw t1, 4(a1)
#endif
    xor t0, t0, s7
    xor t1, t1, s6
    or t0, t0, t1
    seqz a0, t0
    ret

.balign 4
trap_entry:
    csrr t1, mcause
    csrr t2, mepc
    sw t1, 4(s0)
    sw t2, 8(s0)
    li t0, 0x4d53eeee
    sw t0, 0(s0)
#ifdef LIVE_CHECK
    j stopped
#else
    j terminal
#endif

#ifdef BEFORE_RESTORE
setup_gpio:
    lui s10, 0x40000
    addi s10, s10, 0x200
    lui a0, 0x40022
    lw a1, -2036(a0)
    ori a1, a1, 1
    nop
    sw a1, -2036(a0)
    nop
    nop
    lw a1, 4(s10)
    andi a1, a1, -4
    sw a1, 4(s10)
    lw a1, 0x68(s10)
    andi a1, a1, -64
    sw a1, 0x68(s10)
    lw a1, 0x6c(s10)
    andi a1, a1, -16
    sw a1, 0x6c(s10)
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
    lw a1, 4(s10)
    ori a1, a1, 2
    sw a1, 4(s10)
    j test_start
#endif
