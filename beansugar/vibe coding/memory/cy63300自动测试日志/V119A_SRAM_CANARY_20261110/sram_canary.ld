OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  canary (rwx) : ORIGIN = 0x20008000, LENGTH = 0x7000
}
SECTIONS {
  .init : { KEEP(*(.init)) } > canary
  .text : { *(.text .text.*) } > canary
  .rodata : { *(.rodata .rodata.*) } > canary
  .data : { *(.data .data.*) } > canary
  .bss (NOLOAD) : { *(.bss .bss.* COMMON) } > canary
  __stack_top = 0x20020000;
  /DISCARD/ : { *(.comment) *(.eh_frame*) *(.riscv.attributes) }
}
