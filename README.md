# Rust操作系统框架（微内核）

本项目旨在构建一个采用微内核架构的通用操作系统框架，目标适配 RISC-V 与 x86_64 等硬件平台，强调模块化解耦、联合调度算法与性能数据采集，并在 Raspberry Pi 上进行 Linux 内核定制与测试。

## 目标与特性
- 微内核架构：核心最小化，驱动与系统服务外移为独立服务器（user-space/isolated servers）。
- 模块化设计：硬件适配层（HAL）与系统服务隔离，平台相关性最小化。
- 联合调度模型：针对混合任务场景（CPU-bound 与 IO/latency-sensitive），动态分类与联合调度（RR + EDF/WFQ 混合）。
- 数据采集：内核内插桩与 Linux 上 Perf/eBPF 采样，收集任务响应时间、CPU 利用率等关键指标。
- 跨平台与测试：QEMU 上运行（x86_64、riscv64），Raspberry Pi 上进行 Linux 内核定制、交叉编译与调度算法实验。

## 开发记录

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

### M1
</summary>
</details>