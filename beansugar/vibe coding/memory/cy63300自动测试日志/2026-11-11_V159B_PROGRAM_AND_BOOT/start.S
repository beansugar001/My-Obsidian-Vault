    .section .init,"ax",@progbits
    .globl _start
    .type _start,@function
    .option norvc
_start:
    la sp, __stack_top
    call v159_main
1:  j 1b
    .size _start, .-_start

