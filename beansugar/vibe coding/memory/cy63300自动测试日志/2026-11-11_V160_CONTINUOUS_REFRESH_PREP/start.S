    .section .init,"ax",@progbits
    .globl _start
    .type _start,@function
    .option norvc
_start:
    la sp, __stack_top
    call v160_main
1:  j 1b
    .size _start, .-_start

