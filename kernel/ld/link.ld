ENTRY(_start)

/* 高半区虚拟基址与物理加载基址 */
KERNEL_VBASE = 0xFFFFFFFF80000000;
KERNEL_LBASE = 0x00200000;         /* 2MB对齐，适合大页 */

/* VMA从虚拟基址开始 */
. = KERNEL_VBASE;

PHDRS
{
  text   PT_LOAD FLAGS(5); /* R X */
  rodata PT_LOAD FLAGS(4); /* R */
  data   PT_LOAD FLAGS(6); /* R W */
}

SECTIONS
{
  /* 内核物理起始地址 */
  kernel_physical_start = KERNEL_LBASE;

  /* 代码段：VMA=虚拟地址, LMA=物理地址 */
  .text ALIGN(4K) : AT(KERNEL_LBASE)
  {
    KEEP(*(.text._start))  /* 确保_start在最前面 */
    *(.text .text.*)
  } :text
  
  /* RO数据紧接代码段 */
  .rodata ALIGN(4K) : AT(LOADADDR(.text) + SIZEOF(.text))
  {
    *(.rodata .rodata.*)
    *(.got .got.*)         /* GOT表通常放在这里 */
  } :rodata
  
  /* 数据段 */
  .data ALIGN(4K) : AT(LOADADDR(.rodata) + SIZEOF(.rodata))
  {
    *(.data .data.*)
  } :data
  
  /* BSS段：没有AT()，但需要设置加载地址到物理内存末尾 */
  .bss ALIGN(4K) : 
  {
    __bss_start = . - KERNEL_VBASE;  /* 物理地址 */
    *(.bss .bss.* COMMON)
    . = ALIGN(4K);
    __bss_end = . - KERNEL_VBASE;    /* 物理地址 */
  } :data
  
  /* 内核边界符号 */
  kernel_virtual_end = .;
  kernel_physical_end = LOADADDR(.data) + SIZEOF(.data) + SIZEOF(.bss);
  
  /* 栈空间 */
  .stack ALIGN(4K) : 
  {
    . += 64K;
    __stack_top = .;
  }
  
  /* 丢弃不需要的段 */
  /DISCARD/ : {
    *(.comment)
    *(.note.gnu.property)
    *(.eh_frame)
  }
}