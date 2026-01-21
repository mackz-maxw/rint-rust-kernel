# 操作系统启动流程详解

## 概述

本文档详细说明了 RINT Rust 微内核在 x86_64 架构下的启动流程，从硬件加电到内核初始化完成的完整过程。

## 启动步骤详解

### 第一步：硬件初始化（BIOS/UEFI）

当计算机通电后，CPU 首先执行固件（BIOS 或 UEFI）中的代码：

1. **加电自检（POST）**
   - CPU 从固定地址开始执行固件代码
   - 检测并初始化硬件（内存、显卡、存储设备等）
   - 建立基本的运行环境

2. **引导设备选择**
   - 固件根据启动顺序查找引导设备（硬盘、USB、网络等）
   - 读取引导扇区或 ESP（EFI System Partition）

### 第二步：引导加载器（Limine Bootloader）

本项目使用 Limine 作为引导加载器，它负责加载内核并转移控制权：

1. **Limine 初始化**
   - Limine 从 ISO 镜像或磁盘被 BIOS/UEFI 加载
   - 读取配置文件 `limine.conf` 获取启动参数
   - 准备进入 64 位长模式（x86_64）

2. **内核加载**
   ```
   配置文件示例（limine.conf）：
   /Rint Kernel
   protocol: limine
   path: boot():/boot/kernel.bin
   ```
   - Limine 将内核 ELF 文件 `kernel.bin` 加载到内存
   - 根据 ELF 程序头（PHDR）将各个段映射到正确的虚拟地址
   - 设置页表，启用高半区内核（高地址空间）映射

3. **跳转到内核入口**
   - Limine 查找 ELF 中的 `ENTRY(_start)` 符号
   - 设置基本的执行环境（栈、CPU 模式等）
   - 跳转到内核的 `_start` 函数

### 第三步：汇编入口（_start）

内核的第一段代码是用汇编编写的引导代码：

```asm
.section .text._start
.global _start
_start:
    lea rsp, [rip + stack_top]    # 设置栈指针
    call kstart                    # 调用 Rust 主函数
1:  hlt                            # 如果返回则停机
    jmp 1b
```

**关键步骤：**

1. **栈设置**
   - `lea rsp, [rip + stack_top]`：设置栈指针指向临时栈的顶部
   - 临时栈在 `.bss.stack` 段中预留（本项目中为 32KB）
   - 使用位置无关寻址（RIP-relative）确保代码可重定位

2. **调用 Rust 代码**
   - `call kstart`：跳转到 Rust 编写的内核主函数
   - 此时 CPU 已经在 64 位长模式，栈已就绪

3. **异常处理**
   - 如果 `kstart` 意外返回，执行 `hlt` 指令停止 CPU
   - 无限循环确保 CPU 不会执行到未定义的内存区域

### 第四步：Rust 内核初始化（kstart）

进入 Rust 代码后，内核开始初始化各个子系统：

```rust
pub extern "C" fn kstart() -> ! {
    init_serial();                  // 1. 初始化串口
    banner();                       // 2. 打印启动横幅
    
    // TODO: 后续初始化步骤
    // - 设置 GDT（全局描述符表）
    // - 设置 IDT（中断描述符表）
    // - 初始化页表和内存管理
    // - 初始化定时器
    // - 启动调度器
    
    kprintln!("RINT KERNEL: init OK");
    interrupts::disable();          // 3. 禁用中断
    
    loop { hlt(); }                 // 4. 进入空闲循环
}
```

**初始化阶段：**

1. **串口初始化（init_serial）**
   - 配置 COM1 串口（端口 0x3F8）用于调试输出
   - 在 QEMU 中可通过 `-serial stdio` 查看输出

2. **打印启动信息（banner）**
   - 输出内核版本、架构、许可证等信息
   - 确认串口工作正常

3. **禁用中断**
   - 在设置 IDT 之前禁用中断，避免未定义的中断处理
   - 后续会重新启用中断

4. **进入主循环**
   - 当前版本执行 `hlt` 指令等待中断（节能）
   - 未来版本会启动调度器和任务管理

### 第五步：未来扩展（计划中）

以下是后续 Milestone 计划实现的功能：

1. **中断和异常处理**
   - 设置 IDT（中断描述符表）
   - 实现中断处理函数（时钟、键盘、系统调用等）

2. **内存管理**
   - 物理内存分配器（页帧分配）
   - 虚拟内存管理（页表管理）
   - 堆分配器（动态内存）

3. **任务调度**
   - 实现联合调度器（RR + EDF/WFQ）
   - 上下文切换
   - 多任务支持

4. **系统服务**
   - 进程管理
   - IPC（进程间通信）
   - 设备驱动

## 完整启动时序图

```
┌─────────────────┐
│  硬件上电       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  BIOS/UEFI      │
│  - POST         │
│  - 硬件检测     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Limine         │
│  - 读取配置     │
│  - 加载内核     │
│  - 设置分页     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  _start (ASM)   │
│  - 设置栈       │
│  - 调用 kstart  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  kstart (Rust)  │
│  - 初始化串口   │
│  - 打印横幅     │
│  - 系统初始化   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  内核主循环     │
│  (调度器等)     │
└─────────────────┘
```

## 调试技巧

### 查看启动日志

使用 QEMU 时，串口输出会显示在终端：

```bash
bash scripts/qemu.sh
```

预期输出：
```
==============================
 RINT Rust Microkernel (M1) 
 Arch: x86_64 | Boot: Limine | License: Apache-2.0 
==============================
RINT KERNEL: init OK
```

### 检查 ELF 文件

查看内核 ELF 的程序头和虚拟地址：

```bash
readelf -W -l build/iso/boot/kernel.bin
```

查看符号表确认 `_start` 位置：

```bash
readelf -s build/iso/boot/kernel.bin | grep _start
```

### 常见问题

1. **"lower half PHDRs not allowed" 错误**
   - 原因：程序头（PHDR）位于低地址空间
   - 解决：在 `link.ld` 中确保 VMA 在高半区（0xFFFFFFFF80000000 以上）

2. **启动后无输出**
   - 检查串口初始化代码
   - 确认 QEMU 使用了 `-serial stdio` 参数
   - 检查链接脚本中栈的设置

3. **三重错误（Triple Fault）**
   - 原因：未设置 IDT 时触发了中断
   - 解决：确保在 IDT 设置前禁用中断

## 参考资料

- [Limine 引导协议](https://github.com/limine-bootloader/limine)
- [OSDev Wiki - Boot Sequence](https://wiki.osdev.org/Boot_Sequence)
- [x86_64 Long Mode](https://wiki.osdev.org/Long_Mode)
- 项目 README.md 中的 M1 开发记录
