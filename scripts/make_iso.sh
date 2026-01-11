#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
ISO_DIR="${BUILD_DIR}/iso"
KERNEL_BIN="${ROOT_DIR}/target/x86_64-rint/debug/rint-kernel"
LIMINE_DIR="${BUILD_DIR}/limine"

mkdir -p "${ISO_DIR}/boot" "${LIMINE_DIR}"

if ! command -v xorriso >/dev/null; then
  echo "Please install xorriso (sudo apt-get install xorriso)" >&2
  exit 1
fi
if ! command -v qemu-system-x86_64 >/dev/null; then
  echo "Please install QEMU (sudo apt-get install qemu-system-x86)" >&2
  exit 1
fi

# Build limine from upstream if missing
if [ ! -d "${LIMINE_DIR}/.git" ]; then
  git clone --depth=1 https://github.com/limine-bootloader/limine.git "${LIMINE_DIR}"
  make -C "${LIMINE_DIR}" -j
fi

# Build kernel
cargo +nightly build -Z build-std=core,compiler_builtins,alloc --target kernel/x86_64-rint.json

# Prepare ISO contents
cp "${KERNEL_BIN}" "${ISO_DIR}/boot/kernel.bin"
cp "${ROOT_DIR}/limine.cfg" "${ISO_DIR}/limine.cfg"
cp "${LIMINE_DIR}/limine-bios.sys" "${ISO_DIR}/limine-bios.sys"
cp "${LIMINE_DIR}/limine-bios-cd.bin" "${ISO_DIR}/limine-bios-cd.bin"
cp "${LIMINE_DIR}/limine-bios-pc.bin" "${ISO_DIR}/limine-bios-pc.bin"

# Create ISO
xorriso -as mkisofs \
  -b limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot limine-bios-pc.bin \
  -o "${BUILD_DIR}/rint-m1.iso" "${ISO_DIR}"

# Deploy limine to ISO
"${LIMINE_DIR}/limine-deploy" "${BUILD_DIR}/rint-m1.iso"

echo "ISO created: ${BUILD_DIR}/rint-m1.iso"
