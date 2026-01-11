# Rust操作系统框架（微内核）

本项目旨在构建一个采用微内核架构的通用操作系统框架，目标适配 RISC-V 与 x86_64 等硬件平台，强调模块化解耦、联合调度算法与性能数据采集，并在 Raspberry Pi 上进行 Linux 内核定制与测试。

## 目标与特性
- 微内核架构：核心最小化，驱动与系统服务外移为独立服务器（user-space/isolated servers）。
- 模块化设计：硬件适配层（HAL）与系统服务隔离，平台相关性最小化。
- 联合调度模型：针对混合任务场景（CPU-bound 与 IO/latency-sensitive），动态分类与联合调度（RR + EDF/WFQ 混合）。
- 数据采集：内核内插桩与 Linux 上 Perf/eBPF 采样，收集任务响应时间、CPU 利用率等关键指标。
- 跨平台与测试：QEMU 上运行（x86_64、riscv64），Raspberry Pi 上进行 Linux 内核定制、交叉编译与调度算法实验。

## 开发记录&规划

<details>
<summary>

### M0 - 含创建基本仓库结构与能在本机/WSL 运行的 sched-sim 原型文件
</summary>

一：需要的工具
在 Windows 上启用 WSL2（Ubuntu）并在 WSL 中完成 M0（最少阻力）。同时在 Windows 上安装 VS Code 并安装 Remote - WSL 插件

二：安装与准备
- 在 Windows 上安装 WSL2（微软文档），并安装 Ubuntu（或 Debian）。
    ```Powershell
    wsl --install
    ```
- 在 WSL 里安装必要包（示例 Ubuntu 命令）：
  - 再wsl设置中，可以更改.wslconfig file，包括是否镜像主机的代理
  sudo apt update
  sudo apt install -y build-essential curl git pkg-config cmake python3 python3-pip clang lld binutils qemu-system qemu-user-static gcc-aarch64-linux-gnu
- 在 WSL 中安装 Rust：
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source $HOME/.cargo/env

三：配置 Rust targets（在 WSL 或 Windows 的 rustup 下执行）
- 在 WSL（或 Windows）添加常用 target：
  rustup toolchain install stable
  rustup default stable
  rustup target add aarch64-unknown-linux-gnu        # for sched-sim on RPi
  rustup target add riscv64gc-unknown-none-elf      # optional, may need extra toolchain
  **注意：裸机目标如 x86_64-unknown-none 通常需要自定义 target json 和 lld。M0 可先跳过裸机 target 的完整构建。**

四：创建仓库骨架
- cargo new rint-rust-kernel && cd rint-rust-kernel

1. 已创建文件/目录（见仓库根）
   - Cargo.toml（workspace）
   - .cargo/config.toml（占位）
   - crates/sched-sim/src/main.rs（仿真原型）
   - scripts/qemu-run-x86_64.sh、scripts/perf/run_150_overload.sh
   - .gitignore

2. 建议执行流程（推荐在 WSL2 中）
   - 安装 Rust & 目标（见步骤三）
   - 在仓库根运行：
     - cargo build -p sched-sim
     - cargo run -p sched-sim
   - 如果在 WSL 中且安装了 perf，可运行 scripts/perf/run_150_overload.sh

3. 验证标准（M0 完成条件）
   - 仓库被初始化并提交到本地 git。
   - 在本地（Windows 或 WSL）能够成功构建并运行 sched-sim（打印 epoch 输出）。
   - .cargo/config.toml 已放置（后续 M1 填写更精确的 target/linker）。

五：初始化并运行（实际命令）
- git仓库初始化并连接远程仓库
  git add .
  git commit -m "M0: init workspace + sched-sim prototype"
  git remote add origin https://github.com/mackz-maxw/rint-rust-kernel.git
  git branch -M main
  git push -u origin main
- 构建并运行 sched-sim
  **在项目根**
  cargo build -p sched-sim --release
  **运行**
  ./target/release/sched-sim

六：常见问题与排查
- 如果 cargo build 在 Windows 上报找不到 rand crate：在 crates/sched-sim/Cargo.toml 里添加 rand 依赖（我在 M0 假设存在，若没有请添加）：
  [package]
  name = "sched-sim"
  version = "0.1.0"
  edition = "2021"

  [dependencies]
  rand = "0.8"
- 若在 WSL 中运行出现 perf 命令找不到，先安装 perf（Ubuntu 包名 linux-tools-$(uname -r) 或 linux-perf），或直接运行 binary。
- 裸机/内核目标编译失败：这是正常的，裸机构建需要 linker/target json 与 bootloader，留到 M1 处理。

</details>

<details>
<summary>

### M1 - （工作中）
</summary>
</details>

</details>

<details>
<summary>

### 未来开发规划
</summary>

## 总体方向补充

- **Linux ABI 兼容子集**：在不牺牲微内核/模块化原则的前提下，逐步实现一套面向“无界面、服务型”应用的 Linux ABI 子集，使常见的 Linux 用户态程序（特别是使用标准 C 接口或 Rust/musl 静态链接的服务）可以在内核之上运行或通过兼容层运行。
- **嵌入式 AI 服务场景**：面向嵌入式AI：注重稳定的I/O、网络栈、推理引擎/推理服务运行环境，对 GUI 要求低，对可配置度和可观测性要求高。
- 实现路径上，优先保证 **调度/时序/metrics 可靠**，在此基础上引入 **Linux ABI 兼容层 + AI 服务运行环境**，而不是从一开始就覆盖完整桌面/服务器级 Linux ABI。

## M1 – 裸机内核最小可启动（QEMU x86_64）

**目标**：让 kernel 在 x86_64-unknown-none 上通过 QEMU 启动，跑到 kernel_main 并有可观测输出（串口/屏幕）。

**主要工作**

- 引导/启动链路  
  - 为 kernel 增加启动入口与 linker script，或集成 bootloader crate。  
  - 衔接 `_start` 到 `kernel::kernel_main`。

- 最小平台层  
  - 在 `arch-x86_64` 初步实现 IDT/GDT、基本中断屏蔽。  
  - 从 arch-x86_64 装配一个真正的 `Hal<T, I, C>` 替换 `hal::global` 的 dummy（可以先用 stub timer，但由 arch 提供）。

- QEMU 脚本  
  - 填充 scripts/qemu-run-x86_64.sh，使用内核镜像启动 QEMU，串口输出 “hello kernel / epoch …” 等。

**验收标准**

- `cargo build -p kernel --target x86_64-unknown-none` 成功。  
- scripts/qemu-run-x86_64.sh 能在 QEMU 中看到来自内核的输出（如 “kernel booted”）。

---

## M2 – HAL 抽象落地 & 定时器/中断驱动

**目标**：让 HAL 真正驱动时钟中断和基本 IRQ，支持调度器依赖的 Timer/IrqCtl 能力，为后续 Linux ABI 兼容层和 AI 服务提供稳定的时间与中断基础。

**主要工作**

- 完善 HAL 接口实现  
  - 在 `arch-x86_64` 中实现 `Timer/IrqCtl/ContextSwitch`，并装配成 `hal::Hal`。  
  - 在 kernel 中移除对 `DummyTimer/DummyIrq/DummyCtx` 的依赖。

- 时钟中断与 Tick  
  - 设置 APIC/HPET/HPET 之一为 tick 源，实现 `Timer::now_ms` 与 `schedule_tick_in`。  
  - 在中断处理函数里驱动一个简单的 `tick` 计数器，供调度器调用。

- 构建配置  
  - 在 .cargo/config.toml 中确认 `linker`、`rustflags` 与 arch 层产物匹配。  

**验收标准**

- 内核在 QEMU 下运行时，实时时钟递增可见（例如每 N 毫秒打印一次 tick）。  
- 关闭 dummy HAL 后，kernel 仍能成功编译和运行。

---

## M3 – 联合调度器内核集成（RR + EDF/WFQ 原型）

**目标**：把当前在 crates/sched-sim 里的思路真正跑在内核里，通过硬件定时器驱动 `scheduler::joint::JointScheduler`，为后续“多 AI 服务进程 + Linux ABI 进程”提供基础调度能力。

**主要工作**

- 调度器 crate 完善  
  - 在 crates/scheduler 中补齐联合调度模型需要的接口（如 context handle、就绪队列管理）。  
  - 引入 heapless 等依赖到 crates/scheduler/Cargo.toml。

- 内核主循环 & Tick 挂钩  
  - 在 kernel/src/main.rs 中，把当前的 `loop { sched.tick(); }` 改为：  
    - 在时钟中断 handler 中调用 `sched.tick()`。  
    - 支持从 `JointScheduler` 触发 `ContextSwitch`，切换到下一个任务。

- 与 sched-sim 的对齐  
  - 用 crates/sched-sim 的负载生成模型，推导出 JointScheduler 的参数与策略，保持实验结果可比对。  
  - 增强 sched-sim，支持纯 RR 和 “联合调度” 两种模式切换，方便对比。

**验收标准**

- 在 QEMU 内核中，联合调度器可以在一组内核任务/线程上轮转执行（哪怕任务只是 busy-loop + 标记 ID）。  
- sched-sim 可以打印 RR 与 联合调度 两种模式下的 epoch 指标，对比趋势符合预期（如 CPU 利用率、平均响应时间）。

---

## M4 – 指标采集与 Linux/Perf 分析链路

**目标**：打通内核端 & Linux 用户态侧的全链路指标采集，支撑“150% 超负荷场景下联合调度相对 RR 的 10%/20% 优化”这类结论，同时为后续 AI 服务的 SLO（延迟、抖动）打基础。

**主要工作**

- 内核端 metrics  
  - 扩展 `metrics::Recorder` 为事件缓冲区（如环形 buffer + 简单事件类型：调度、重分类、IRQ 等）。  
  - 在 `scheduler::joint::JointScheduler` 中调用 `Recorder::on_schedule/on_reclass`，记录关键事件。

- 数据导出通道  
  - 在内核中提供简单日志/共享内存导出：  
    - 最小实现：通过串口打印 CSV 样式事件。  
    - 后续可以实现一个 debug-only 的共享内存缓冲区供宿主机采集。

- Perf / eBPF + Linux 实验  
  - 借助 scripts/perf/run_150_overload.sh，完善在 Linux 上跑 crates/sched-sim 的 perf 脚本（CPU 利用率、分支预测、cache miss 等）。  
  - 定义统一指标：如“平均响应时间”“调度开销占比”等，撰写对照实验步骤。

**验收标准**

- 内核在 QEMU 中可输出调度事件（至少 task_id + timestamp）。  
- 在 Linux 上，scripts/perf/run_150_overload.sh 能稳定生成对比 RR/联合调度的 Perf 统计，并可支撑“负载 150% 时调度开销下降 ~10%、CPU 利用率提升 ~20%”的复现实验。

---

## M5 – 多环境移植与 Linux ABI 子集验证（含 Raspberry Pi）

**目标**：在保持 Linux ABI 兼容子集设计的前提下，将当前内核与工具链移植到 RISC-V 与 Raspberry Pi（aarch64 Linux）环境，在多平台上验证调度行为和 ABI 兼容性。

**主要工作**

- RISC-V 裸机 bring-up  
  - 在 `arch-riscv64` 实现对 `Timer/IrqCtl/ContextSwitch` 的 RISC-V 版本（SBI、S-mode timer、PLIC 等）。  
  - 新增 QEMU RISC-V 启动脚本，跑通 kernel 的 RISC-V 版本，并验证联合调度 + metrics 的基本行为。

- Raspberry Pi + Linux/交叉编译链路  
  - 利用 .cargo/config.toml 中的 aarch64-unknown-linux-gnu 目标，将 crates/sched-sim 和后续 Linux ABI demo 服务交叉编译并在 RPi 上运行。  
  - 在 RPi 上通过 Perf/eBPF 分析调度算法与 AI 类工作负载（如网络 + CPU）的表现。

- Raspberry Pi 裸机/半裸机场景探索  
  - 预研在 RPi 裸机上运行本内核的可行性：时钟/中断/HAL 适配，以及在其上跑一小部分 Linux ABI 程序。  
  - 记录与现有 Linux 内核定制方案的差异和折中点。

- 内核恐慌排查流程  
  - 总结在 RPi 或其他真实硬件上遇到的 panic/backtrace，并形成一套最小 reproducible case + 调试文档。

**验收标准**

- kernel 可在 QEMU RISC-V 启动，基本输出/调度/metrics 功能可用。  
- sched-sim 以及至少一个 Linux ABI demo 服务可在 RPi 上运行并被 perf 分析。  
- 有至少一个真实工作负载（如网络 + 轻量 AI 推理）下的 Perf 报告，用于印证联合调度与 Linux ABI 子集组合的收益趋势。

---

## M6 – 微内核化改造：用户态服务、Linux 兼容服务器 & IPC 基础

**目标**：从“单体+调度实验内核”演进为“微内核骨架”，并将 Linux ABI 子集实现收敛到一个或多个用户态“Linux 兼容服务器”中，使驱动和系统服务尽量移出内核，同时保持对嵌入式 AI 场景友好的 IPC 模型。

**主要工作**

- 进程/地址空间抽象  
  - 在 kernel 中设计轻量的任务/进程结构：地址空间 + 能力/handle + 调度元信息（可复用 `scheduler::TaskMeta` 中的部分字段）。  
  - 为内核态/用户态任务提供统一 ID 和 handle 机制。

- IPC/系统调用路径  
  - 设计最小 microkernel syscall 集：send/recv、yield、map/unmap page 等。  
  - 增加 IPC 信道（队列或共享内存）原语，用于 user-space driver、Linux 兼容服务器与其他服务之间通信。

- Linux 兼容服务器  
  - 将部分 Linux ABI syscall 逻辑迁移至用户态“Linux 服务器”进程，由内核通过 IPC 转发请求。  
  - 为 Linux 兼容服务器配置合适的调度策略（如权重、优先级），保障多个 AI 服务并发场景下的整体稳定性。

- 用户态服务原型  
  - 把一个简单服务（如日志服务或计时服务）从内核中剥离为用户态进程，由调度器管理。  
  - 参照 asterinas、moss-kernel 对 capability/async I/O 的处理方式，形成自己的最小子集。

**验收标准**

- QEMU 中能运行至少一个 Linux 兼容服务器进程和一个非 Linux ABI 的原生微内核服务，两者通过 IPC 协同工作。  
- 内核中与调度/IPC/ABI 转发相关的代码清晰分层，HAL/arch 层与上层 ABI/服务逻辑解耦。

---

## M7 – 联合调度 + 嵌入式 AI 场景的深度实验与文档

**目标**：围绕“Alexa 类嵌入式 AI 助手”构建一套可运行的 demo，并在多平台（QEMU x86_64、RISC-V、Raspberry Pi）上评估：联合调度 + Linux ABI 子集 + 微内核架构的综合效果。

**主要工作**

- 嵌入式 AI demo 设计  
  - 选定一个轻量 AI 场景（如关键词唤醒 + 云端 NLU，或本地小模型推理）。  
  - 明确所需依赖：音频 I/O、网络 TCP/TLS、简单存储等，并映射到 Linux ABI 子集与微内核服务。

- 服务部署与移植  
  - 在 QEMU 上验证 AI demo 的功能与调度行为，然后迁移到 Raspberry Pi 等真实硬件。  
  - 根据平台差异（x86_64/RISC-V/aarch64）调整 HAL 与驱动实现，保持上层服务和 ABI 接口尽可能不变。

- 性能与 SLO 评估  
  - 在 100%/150% 负载下，比较：纯 RR、联合调度、不同优先级配置下 AI 请求延迟/抖动、CPU 利用率。  
  - 使用 Perf/eBPF 和内核 metrics 共同分析“AI 请求路径”上的 CPU 开销与调度开销。

- 文档化与对比  
  - 在 README.md 中补全从 M0–M7 的演进说明，特别是 Linux ABI 子集 + 多平台可移植性 + 嵌入式 AI 场景的设计取舍。  
  - 对照 asterinas / moss-kernel，总结本项目在“微内核 + Linux 兼容层 + 联合调度 + 嵌入式 AI”组合上的特色。

**验收标准**

- 一套可运行的嵌入式 AI demo（在 QEMU 和至少一个真实硬件平台上，如 Raspberry Pi），能完成基本的“请求-响应”闭环。  
- 一组可复现的实验脚本 + 报告，定量展示在 AI 工作负载和多平台环境下，联合调度 + Linux ABI 兼容层相对基础 RR/单一策略的优势。
</details>