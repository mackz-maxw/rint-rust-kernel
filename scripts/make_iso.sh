#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
ISO_DIR="${BUILD_DIR}/iso"
KERNEL_BIN="${ROOT_DIR}/target/x86_64-rint/debug/rint-kernel"
LIMINE_DIR="${BUILD_DIR}/limine"

mkdir -p "${ISO_DIR}/boot" "${ISO_DIR}/EFI/BOOT" "${LIMINE_DIR}"

# 必需：xorriso
if ! command -v xorriso >/dev/null; then
  echo "Please install xorriso (sudo apt-get install xorriso)" >&2
  exit 1
fi

# 可选：QEMU（CI 中不强制）
if ! command -v qemu-system-x86_64 >/dev/null; then
  echo "Warning: QEMU not found (sudo apt-get install qemu-system-x86). ISO build will continue without QEMU." >&2
fi

# 获取 Limine binary release；若 CLI 不存在则执行 make（binary 分支不提供 ./configure）
if [ ! -d "${LIMINE_DIR}/.git" ]; then
  git clone https://codeberg.org/Limine/Limine.git --branch=v10.6.2-binary --depth=1 "${LIMINE_DIR}"
fi

# 构建 CLI：优先检查根目录 limine，其次 bin/limine
if [ ! -x "${LIMINE_DIR}/limine" ] && [ ! -x "${LIMINE_DIR}/bin/limine" ]; then
  (cd "${LIMINE_DIR}" && make)
fi

# 解析 Limine 产物路径（bin 或 share）
find_limine_file() {
  local fname="$1"
  local candidates=(
    "${LIMINE_DIR}/bin/${fname}"
    "${LIMINE_DIR}/share/${fname}"
    "${LIMINE_DIR}/${fname}"
  )
  for p in "${candidates[@]}"; do
    if [ -f "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

UEFI_CD_BIN="$(find_limine_file 'limine-uefi-cd.bin')" || { echo "Missing limine-uefi-cd.bin"; exit 1; }
BIOS_CD_BIN="$(find_limine_file 'limine-bios-cd.bin')" || { echo "Missing limine-bios-cd.bin"; exit 1; }
BIOS_SYS_BIN="$(find_limine_file 'limine-bios.sys')"   || { echo "Missing limine-bios.sys"; exit 1; }
BOOTX64_EFI="$(find_limine_file 'BOOTX64.EFI')"         || { echo "Missing BOOTX64.EFI"; exit 1; }

# 选择配置文件：优先使用 limine.conf；若只存在 limine.cfg，复制为 limine.conf 并提示
CONFIG_SRC=""
if [ -f "${ROOT_DIR}/limine.conf" ]; then
  CONFIG_SRC="${ROOT_DIR}/limine.conf"
elif [ -f "${ROOT_DIR}/limine.cfg" ]; then
  echo "Warning: using limine.cfg as limine.conf (please migrate to limine.conf format per USAGE.md)" >&2
  CONFIG_SRC="${ROOT_DIR}/limine.cfg"
else
  echo "Missing limine.conf (or limine.cfg). Please add a config per CONFIG.md." >&2
  exit 1
fi

# 编译内核（按需改为 --release 并同步 KERNEL_BIN）
cargo +nightly build -Z build-std=core,compiler_builtins,alloc --target kernel/x86_64-rint.json

# 准备 ISO 内容（对齐 USAGE.md）
cp "${KERNEL_BIN}" "${ISO_DIR}/boot/kernel.bin"

# 将 limine.conf 和 limine-bios.sys 放在 ISO 根目录（USAGE.md 支持 root/limine/boot/boot/limine）
cp "${CONFIG_SRC}" "${ISO_DIR}/limine.conf"
cp "${BIOS_SYS_BIN}" "${ISO_DIR}/limine-bios.sys"

# CD 引导镜像放到 boot/ 目录，便于在 xorriso 中用相���路径引用
cp "${BIOS_CD_BIN}" "${ISO_DIR}/boot/limine-bios-cd.bin"
cp "${UEFI_CD_BIN}" "${ISO_DIR}/boot/limine-uefi-cd.bin"

# 复制 UEFI 可执行到 EFI/BOOT
cp "${BOOTX64_EFI}" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"

# 生成混合 BIOS/UEFI ISO（完全按 USAGE.md 推荐参数）
xorriso -as mkisofs -R -r -J \
  -b boot/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus \
  -apm-block-size 2048 \
  --efi-boot boot/limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  "${ISO_DIR}" -o "${BUILD_DIR}/rint-m1.iso"

# 对生成的镜像执行 bios-install（替代旧版的 limine-deploy）
LIMINE_CLI=""
if [ -x "${LIMINE_DIR}/bin/limine" ]; then
  LIMINE_CLI="${LIMINE_DIR}/bin/limine"
elif [ -x "${LIMINE_DIR}/limine" ]; then
  LIMINE_CLI="${LIMINE_DIR}/limine"
elif command -v limine >/dev/null; then
  LIMINE_CLI="$(command -v limine)"
else
  echo "Limine CLI not found. Run 'make' in build/limine or install Limine to PATH." >&2
  exit 1
fi

"${LIMINE_CLI}" bios-install "${BUILD_DIR}/rint-m1.iso"

echo "ISO created and installed with Limine: ${BUILD_DIR}/rint-m1.iso"