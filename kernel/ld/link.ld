ENTRY(_start) /* 告诉链接器程序入口符号是 _start（在 kernel/src/main.rs 的汇编里） */

KERNEL_PHYS_BASE = 0x200000;         /* 物理装载地址（2 MiB 对齐，方便跳过固件/引导器区域） */
KERNEL_VIRT_BASE = 0xffffffff80000000; /* 高半区映射基址；Limine 不允许低半区 PHDRs */

PHDRS {
  text   PT_LOAD FLAGS(0x5); /* 可加载、可读可执行：代码段 */
  rodata PT_LOAD FLAGS(0x4); /* 可加载、只读：常量段 */
  data   PT_LOAD FLAGS(0x6); /* 可加载、可读可写：数据和 bss 段 */
}

SECTIONS
{
  /* SECTIONS 中段的出现顺序就是布局顺序。
    先 .text，其起始偏移为 0（对齐到 0x1000）；
    .rodata 紧随 .text 末尾并按 0x1000 对齐；
    .data 紧随 .rodata；.bss 紧随 .data */
  /* 将“虚拟地址基准”（VMA）放到高半区；实际文件装载的物理地址（LMA）仍在 2MiB */
  . = KERNEL_VIRT_BASE;

  .text : ALIGN(0x1000) {
    KEEP(*(.text._start))
    *(.text .text.*)
  } :text AT(KERNEL_PHYS_BASE + (ADDR(.text) - KERNEL_VIRT_BASE))

  .rodata : ALIGN(0x1000) {
    *(.rodata .rodata.*)
  } :rodata AT(KERNEL_PHYS_BASE + (ADDR(.rodata) - KERNEL_VIRT_BASE))

  .data : ALIGN(0x1000) {
    *(.data .data.*)
  } :data AT(KERNEL_PHYS_BASE + (ADDR(.data) - KERNEL_VIRT_BASE))

  .bss : ALIGN(0x1000) {
    *(.bss .bss.* COMMON)
  } :data AT(KERNEL_PHYS_BASE + (ADDR(.bss) - KERNEL_VIRT_BASE))
}