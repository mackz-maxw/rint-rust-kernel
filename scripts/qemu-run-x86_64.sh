#!/usr/bin/env bash
set -euo pipefail
echo "M0: 占位 QEMU 启动脚本（需在后续 M1/M4 填充引导镜像）"
# 示例命令（后续需要替换 kernel Image / bootloader）
# qemu-system-x86_64 -kernel build/kernel.bin -m 1G -nographic -append "console=ttyS0"