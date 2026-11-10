OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  flash (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
  ram   (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}
SECTIONS {
  .init : { KEEP(*(.init)) } > flash
  .text : { *(.text .text.*) *(.rodata .rodata.*) } > flash
  . = ALIGN(4);
  .data : { *(.data .data.*) } > ram AT>flash
  .bss (NOLOAD) : { *(.bss .bss.* COMMON) } > ram
  __stack_top = ORIGIN(ram) + LENGTH(ram);
  /DISCARD/ : { *(.comment) *(.eh_frame*) *(.riscv.attributes) }
}
