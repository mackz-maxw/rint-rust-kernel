#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="${ROOT_DIR}/build/rint-m1.iso"

if [ ! -f "${ISO}" ]; then
  echo "ISO not found: ${ISO}. Run scripts/make_iso.sh first." >&2
  exit 1
fi

qemu-system-x86_64 \
  -machine q35 \
  -m 256M \
  -serial stdio \
  -display none \
  -cdrom "${ISO}" \
  -no-reboot \
  -d guest_errors
