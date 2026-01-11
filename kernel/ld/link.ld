OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kstart)

SECTIONS
{
  . = 0x100000;

  /* Place stivale2 header very early so Limine can find it */
  .stivale2hdr : ALIGN(16) {
    KEEP(*(.stivale2hdr))
  }

  .text : ALIGN(16) {
    *(.text .text.*)
  }

  .rodata : ALIGN(16) {
    *(.rodata .rodata.*)
  }

  .data : ALIGN(16) {
    *(.data .data.*)
  }

  .bss : ALIGN(16) {
    *(.bss .bss.* COMMON)
  }

  /DISCARD/ : {
    *(.eh_frame)
    *(.note .note.*)
  }
}
