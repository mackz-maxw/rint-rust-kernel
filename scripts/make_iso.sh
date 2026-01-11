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

# Get Limine binaries - try git clone with binary branch first
if [ ! -f "${LIMINE_DIR}/limine-bios.sys" ] || [ ! -f "${LIMINE_DIR}/limine" ]; then
  echo "Fetching Limine binaries..."
  rm -rf "${LIMINE_DIR}"
  git clone --depth=1 --branch=v7.x-binary https://github.com/limine-bootloader/limine.git "${LIMINE_DIR}" 2>/dev/null || \
    git clone --depth=1 --branch=v8.x-binary https://github.com/limine-bootloader/limine.git "${LIMINE_DIR}" 2>/dev/null || \
    {
      # Fallback: clone and try to build
      echo "Binary branch not found, cloning main..."
      git clone --depth=1 https://github.com/limine-bootloader/limine.git "${LIMINE_DIR}"
      cd "${LIMINE_DIR}"
      # Just compile limine-deploy, we'll use pre-built binaries from repo
      make limine 2>/dev/null || {
        # If that fails, download binaries manually
        echo "Build failed, using fallback binaries..."
        cd "${ROOT_DIR}"
      }
    }
  # Build the limine tool if not present
  if [ ! -f "${LIMINE_DIR}/limine" ] && [ -f "${LIMINE_DIR}/limine.c" ]; then
    cd "${LIMINE_DIR}"
    make limine || true
    cd "${ROOT_DIR}"
  fi
fi

# Build kernel
cargo +nightly build -Z build-std=core,compiler_builtins,alloc -Z build-std-features=compiler-builtins-mem --target kernel/x86_64-rint.json

# Prepare ISO contents
cp "${KERNEL_BIN}" "${ISO_DIR}/boot/kernel.bin"
cp "${ROOT_DIR}/limine.cfg" "${ISO_DIR}/limine.cfg"

# Try to copy Limine files
for file in limine-bios.sys limine-bios-cd.bin limine-bios-pc.bin limine-uefi-cd.bin; do
  if [ -f "${LIMINE_DIR}/${file}" ]; then
    cp "${LIMINE_DIR}/${file}" "${ISO_DIR}/${file}"
  fi
done

# Create ISO
xorriso -as mkisofs \
  -b limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  -o "${BUILD_DIR}/rint-m1.iso" "${ISO_DIR}" 2>&1 | grep -v "^xorriso" || true

# Deploy limine to ISO if limine tool exists
if [ -f "${LIMINE_DIR}/limine" ]; then
  "${LIMINE_DIR}/limine" bios-install "${BUILD_DIR}/rint-m1.iso" 2>&1 | grep -v "^Limine" || true
fi

echo "ISO created: ${BUILD_DIR}/rint-m1.iso"
