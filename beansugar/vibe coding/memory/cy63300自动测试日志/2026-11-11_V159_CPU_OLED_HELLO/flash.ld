OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    flash (rx) : ORIGIN = 0x00000000, LENGTH = 64K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}
SECTIONS {
    .init : { KEEP(*(.init)) } > flash
    .text : { *(.text .text.*) *(.rodata .rodata.* .srodata .srodata.*) } > flash
    .data : { *(.data .data.* .sdata .sdata.*) } > ram AT>flash
    .bss (NOLOAD) : { *(.bss .bss.* .sbss .sbss.* COMMON) } > ram
    .mailbox 0x2000F000 (NOLOAD) : { . += 56; } > ram
    .stack 0x2001F000 (NOLOAD) : { . += 4096; __stack_top = .; } > ram
    ASSERT(SIZEOF(.data) == 0 && SIZEOF(.bss) == 0, "startup only supports read-only data")
    /DISCARD/ : { *(.comment) *(.eh_frame*) }
}

