/* 高半区虚拟基址与物理加载基址 */
KERNEL_VMA = 0xFFFFFFFF80200000; /* 高半区虚拟地址（示例） */
KERNEL_LMA = 0x00200000;         /* 物理加载地址 2MiB */

ENTRY(_start)

PHDRS
{
  text   PT_LOAD FLAGS(5); /* R X */
  rodata PT_LOAD FLAGS(4); /* R */
  data   PT_LOAD FLAGS(6); /* R W */
}

SECTIONS
{
  /* 把链接地址（VMA）移动到高半区 */
  . = KERNEL_VMA;

  .text : ALIGN(16)
  {
    KEEP(*(.text._start))
    *(.text .text.*)
  } :text AT(ADDR(.text) - KERNEL_VMA + KERNEL_LMA)

  .rodata : ALIGN(16)
  {
    *(.rodata .rodata.*)
  } :rodata AT(ADDR(.rodata) - KERNEL_VMA + KERNEL_LMA)

  .data : ALIGN(16)
  {
    *(.data .data.*)
  } :data AT(ADDR(.data) - KERNEL_VMA + KERNEL_LMA)

  .bss : ALIGN(16)
  {
    *(.bss .bss.* COMMON)
  } :data AT(ADDR(.bss) - KERNEL_VMA + KERNEL_LMA)
}