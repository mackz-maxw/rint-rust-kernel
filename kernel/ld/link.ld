ENTRY(_start) /* 显式告诉链接器哪个符号是入口 */

SECTIONS
{
  . = 0x200000; /* Link at 2MiB; Limine will relocate as needed */

  /* ALIGN(N)：段对齐，确保CPU/引导器读取这些结构时满足对齐要求 */
  /* KEEP(...)：告诉链接器不要把该输入节丢弃（即便认为未被引用）。
    这对引导 header 非常重要，因为没有代码引用它，链接器可能会优化掉它 */

  /* 把所有代码段合并到输出的 .text 段，并按 16 字节对齐。
    这里会包含内核函数、全局 asm 定义的启动代码等 */
  .text : ALIGN(16) {
    KEEP(*(.text._start))
    *(.text .text.*)
  }

  /* 只读数据（常量字符串等） */
  .rodata : ALIGN(16) {
    *(.rodata .rodata.*)
  }

  /* 已初始化的可写全局数据 */
  .data : ALIGN(16) {
    *(.data .data.*)
  }

  /* 未初始化的数据 */
  .bss : ALIGN(16) {
    *(.bss .bss.* COMMON)
  }
}