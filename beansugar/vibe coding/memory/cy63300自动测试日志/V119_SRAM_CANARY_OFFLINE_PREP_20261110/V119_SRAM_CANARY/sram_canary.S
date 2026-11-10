    .section .init,"ax",@progbits
    .globl _start
    .type _start,@function
    .option push
    .option norvc
    .option norelax
_start:
    lui     sp, 0x20020              # stack top = 0x20020000
    lui     t0, 0x2000f              # mailbox = 0x2000F000

    li      t1, 0x534D5231           # unique canary magic: "SMR1"
    sw      t1, 0(t0)
    li      t1, 0x119A0010           # unique stage: V119 SRAM canary
    sw      t1, 4(t0)
    li      t1, 0x42454731           # started marker: "BEG1"
    sw      t1, 8(t0)
    fence   iorw, iorw

    li      t1, 0x444F4E45           # done marker: "DONE"
    sw      t1, 12(t0)
    li      t1, 1
    sw      t1, 16(t0)               # completion count
    fence   iorw, iorw
1:
    jal     zero, 1b
    .option pop
    .size _start, .-_start
