# 链接脚本（link.ld）详解

## 概述

链接脚本（Linker Script）是告诉链接器如何组织程序各个部分的配置文件。对于操作系统内核来说，链接脚本至关重要，因为它决定了内核在内存中的布局、各个段的地址以及程序的入口点。

## 本项目的 link.ld 文件

```ld
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
```

## 链接脚本的作用

### 1. 定义内核在内存中的布局

链接脚本决定了：
- 代码段（.text）在哪里
- 只读数据（.rodata）在哪里
- 读写数据（.data）在哪里
- 未初始化数据（.bss）在哪里

这些段的正确组织对内核的安全性和性能都很重要。

### 2. 区分虚拟地址和物理地址

现代操作系统使用虚拟内存，链接脚本需要指定：
- **VMA (Virtual Memory Address)**: 虚拟地址，程序运行时使用的地址
- **LMA (Load Memory Address)**: 加载地址，程序在物理内存中的位置

### 3. 控制程序入口

`ENTRY(_start)` 指定程序的入口点，告诉引导加载器从哪里开始执行。

## 重要概念详解

### 高半区内核（Higher Half Kernel）

**什么是高半区内核？**

高半区内核是指内核代码被链接到虚拟地址空间的高地址部分（通常是 0xFFFFFFFF80000000 以上）。

**为什么使用高半区？**

1. **用户空间保护**
   - 低地址空间（0x0000000000000000 - 0x00007FFFFFFFFFFF）留给用户程序
   - 内核和用户空间明确分离，提高安全性

2. **简化地址管理**
   - 内核始终映射在固定的高地址
   - 每个用户进程可以使用完整的低地址空间

3. **标准约定**
   - x86_64 架构下，高半区内核是普遍做法
   - 与 Linux 等主流操作系统保持一致

**本项目的配置：**

```ld
KERNEL_VMA = 0xFFFFFFFF80200000;  /* 虚拟地址：高半区 */
KERNEL_LMA = 0x00200000;          /* 物理地址：2MB 处 */
```

- VMA 在高地址空间，程序执行时使用这个地址
- LMA 在低地址空间，引导加载器将内核加载到这里
- 引导加载器（Limine）负责设置页表，将 VMA 映射到 LMA

### 程序头（PHDRS）

```ld
PHDRS
{
  text   PT_LOAD FLAGS(5); /* R X - 可读可执行 */
  rodata PT_LOAD FLAGS(4); /* R   - 只读 */
  data   PT_LOAD FLAGS(6); /* R W - 可读可写 */
}
```

**程序头的作用：**

1. **PT_LOAD**: 表示需要加载到内存的段
2. **FLAGS**: 指定段的权限
   - 5 = R + X (可读 + 可执行) - 代码段
   - 4 = R (只读) - 只读数据段
   - 6 = R + W (可读 + 可写) - 数据段

**为什么要分离权限？**

- 现代 CPU 支持 NX (No-Execute) 位
- 代码段设为可执行但不可写，防止代码注入攻击
- 数据段设为可写但不可执行，防止数据被当作代码执行
- 这种分离提高了系统安全性

### 段（SECTIONS）详解

#### .text 段（代码段）

```ld
.text : ALIGN(16)
{
  KEEP(*(.text._start))    /* 保留入口函数 */
  *(.text .text.*)         /* 所有代码 */
} :text AT(ADDR(.text) - KERNEL_VMA + KERNEL_LMA)
```

**关键点：**

1. **KEEP(*(.text._start))**
   - `KEEP` 防止链接器优化掉看似未使用的符号
   - `_start` 是入口函数，必须保留且放在最前面
   - 确保引导加载器能找到正确的入口点

2. **ALIGN(16)**
   - 将段对齐到 16 字节边界
   - 提高 CPU 缓存效率
   - 某些指令要求对齐访问

3. **AT(ADDR(.text) - KERNEL_VMA + KERNEL_LMA)**
   - 设置物理加载地址
   - `ADDR(.text)` 是虚拟地址
   - 计算公式将虚拟地址转换为物理地址

#### .rodata 段（只读数据）

```ld
.rodata : ALIGN(16)
{
  *(.rodata .rodata.*)     /* 字符串常量、常量数组等 */
} :rodata AT(ADDR(.rodata) - KERNEL_VMA + KERNEL_LMA)
```

**包含内容：**
- 字符串字面量（如 "Hello, World!"）
- const 声明的常量
- 其他只读数据

**为什么单独分段？**
- 设置为只读权限，防止意外修改
- 提高安全性，防止攻击者修改常量

#### .data 段（已初始化数据）

```ld
.data : ALIGN(16)
{
  *(.data .data.*)         /* 全局变量、静态变量等 */
} :data AT(ADDR(.data) - KERNEL_VMA + KERNEL_LMA)
```

**包含内容：**
- 已初始化的全局变量
- 已初始化的静态变量

**特点：**
- 需要从磁盘/镜像加载
- 在 ELF 文件中占用空间

#### .bss 段（未初始化数据）

```ld
.bss : ALIGN(16)
{
  *(.bss .bss.* COMMON)    /* 未初始化的全局变量 */
} :data AT(ADDR(.bss) - KERNEL_VMA + KERNEL_LMA)
```

**包含内容：**
- 未初始化的全局变量
- 未初始化的静态变量
- `COMMON` 符号（C 语言遗留特性）

**特点：**
- 不占用 ELF 文件空间
- 加载时由引导加载器或内核清零
- 节省磁盘/镜像空间

## 编写 link.ld 的注意事项

### 1. 虚拟地址与物理地址的一致性

**关键规则：**
```
物理地址 = 虚拟地址 - KERNEL_VMA + KERNEL_LMA
```

**检查方法：**
```bash
readelf -l build/iso/boot/kernel.bin
```

查看输出中的 VirtAddr 和 PhysAddr，确保它们的差值恒定。

### 2. 段的顺序和对齐

**推荐顺序：**
1. `.text` - 代码段（放在最前面）
2. `.rodata` - 只读数据
3. `.data` - 可写数据
4. `.bss` - 未初始化数据

**为什么这样排序？**
- 符合常见的内存保护模式
- 便于设置页表权限（相同权限的段在一起）
- 遵循行业标准

**对齐要求：**
- 最小对齐 4KB（页大小）以便内存保护
- 本项目使用 16 字节对齐（简化实现）
- 生产环境应使用 4096 字节对齐

### 3. 入口点的正确设置

```ld
ENTRY(_start)
```

**要点：**
- `_start` 必须在 `.text._start` 段中定义
- 使用 `KEEP` 防止被优化掉
- 确保 `_start` 是第一个函数（放在 .text 段最前面）

### 4. 高半区地址的选择

**常用的高半区地址：**
- `0xFFFFFFFF80000000` - Linux 内核使用的地址
- `0xFFFFFFFF80200000` - 本项目使用（偏移 2MB）

**为什么偏移 2MB？**
- 前 2MB 可能被 BIOS/引导加载器使用
- 避免与低地址的映射冲突
- 符合 x86_64 大页对齐（2MB）

### 5. 处理引导加载器要求

**Limine 的要求：**
1. ELF 程序头必须在高地址（避免 "lower half PHDRs" 错误）
2. 段必须正确对齐
3. 入口点必须可访问

**常见错误：**
```
错误: lower half PHDRs not allowed
原因: 程序头的虚拟地址在低地址空间
解决: 确保所有段的 VMA 都在高半区
```

### 6. 段的权限设置

**最佳实践：**
```ld
PHDRS
{
  text   PT_LOAD FLAGS(5);  /* R-X: 代码段 */
  rodata PT_LOAD FLAGS(4);  /* R--: 只读数据 */
  data   PT_LOAD FLAGS(6);  /* RW-: 数据段 */
}
```

**安全考虑：**
- 代码段：可读可执行，但不可写
- 只读数据：只读，不可写不可执行
- 数据段：可读可写，但不可执行
- 永远不要设置 RWX（可读可写可执行）权限

### 7. 符号的导出

**重要符号：**
```ld
.text : {
  __text_start = .;
  KEEP(*(.text._start))
  *(.text .text.*)
  __text_end = .;
} :text
```

**用途：**
- 内核代码可以引用 `__text_start` 和 `__text_end`
- 用于内存管理、调试等
- 本项目当前未使用，但建议添加

### 8. 调试信息

**保留调试段：**
```ld
.debug_info 0 : { *(.debug_info) }
.debug_line 0 : { *(.debug_line) }
/* ... 其他 debug 段 */
```

**注意：**
- 调试段不应影响运行时的内存布局
- 使用 `0` 地址表示不加载到内存
- 本项目当前未添加，可以考虑补充

## 验证链接脚本

### 检查 ELF 文件结构

```bash
# 查看程序头
readelf -W -l build/iso/boot/kernel.bin

# 查看段
readelf -W -S build/iso/boot/kernel.bin

# 查看符号
readelf -s build/iso/boot/kernel.bin | grep _start
```

### 预期输出示例

```
Program Headers:
  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
  LOAD           0x001000 0xffffffff80201000 0x0000000000201000 0x001234 0x001234 R E 0x1000
  LOAD           0x003000 0xffffffff80203000 0x0000000000203000 0x000100 0x000100 R   0x1000
  LOAD           0x004000 0xffffffff80204000 0x0000000000204000 0x000200 0x000400 RW  0x1000
```

**检查点：**
- VirtAddr 在高地址（0xFFFFFFFF80000000 以上）
- PhysAddr 在低地址（0x00200000 附近）
- VirtAddr - PhysAddr 的差值对所有段相同
- Flags 正确（代码 R E，数据 RW，只读 R）

## 常见问题和调试

### 问题 1: "lower half PHDRs not allowed"

**原因：**
链接脚本中某些段的虚拟地址在低地址空间。

**解决方法：**
```ld
/* 错误写法 */
. = 0x100000;  // 低地址

/* 正确写法 */
. = 0xFFFFFFFF80200000;  // 高地址
```

### 问题 2: 启动后立即崩溃

**可能原因：**
1. 入口点位置不正确
2. 栈设置有问题
3. 段对齐不正确

**检查方法：**
```bash
readelf -s kernel.bin | grep _start
readelf -s kernel.bin | grep stack_top
```

### 问题 3: 数据段访问错误

**可能原因：**
- .data 或 .bss 的物理地址计算错误
- 页表映射不正确

**调试步骤：**
1. 检查 AT() 表达式的计算
2. 确认引导加载器正确映射了所有段
3. 使用 QEMU 的 `-d` 选项查看内存映射

## 示例：完整的链接脚本模板

```ld
/* 配置常量 */
KERNEL_VMA = 0xFFFFFFFF80200000;
KERNEL_LMA = 0x00200000;

ENTRY(_start)

PHDRS
{
  text   PT_LOAD FLAGS(5);  /* R-X */
  rodata PT_LOAD FLAGS(4);  /* R-- */
  data   PT_LOAD FLAGS(6);  /* RW- */
}

SECTIONS
{
  . = KERNEL_VMA;

  .text : ALIGN(4096) {
    __text_start = .;
    KEEP(*(.text._start))
    *(.text .text.*)
    __text_end = .;
  } :text AT(ADDR(.text) - KERNEL_VMA + KERNEL_LMA)

  .rodata : ALIGN(4096) {
    __rodata_start = .;
    *(.rodata .rodata.*)
    __rodata_end = .;
  } :rodata AT(ADDR(.rodata) - KERNEL_VMA + KERNEL_LMA)

  .data : ALIGN(4096) {
    __data_start = .;
    *(.data .data.*)
    __data_end = .;
  } :data AT(ADDR(.data) - KERNEL_VMA + KERNEL_LMA)

  .bss : ALIGN(4096) {
    __bss_start = .;
    *(.bss .bss.* COMMON)
    __bss_end = .;
  } :data AT(ADDR(.bss) - KERNEL_VMA + KERNEL_LMA)

  __kernel_end = .;

  /DISCARD/ : {
    *(.comment)
    *(.eh_frame)
    *(.note.GNU-stack)
  }
}
```

## 参考资料

- [GNU ld 手册](https://sourceware.org/binutils/docs/ld/)
- [OSDev Wiki - Linker Scripts](https://wiki.osdev.org/Linker_Scripts)
- [Higher Half x86 Bare Bones](https://wiki.osdev.org/Higher_Half_x86_Bare_Bones)
- 本项目的 `kernel/ld/link.ld` 文件
- Limine 引导协议文档
