# Rint Rust Microkernel — M1 Scaffold

Target: x86_64 • Boot: Limine (stivale2) • License: Apache-2.0 • Dev: WSL2 Ubuntu 22

## What works
- Minimal stivale2 header and entry to `kstart` with temporary stack
- Serial logging on COM1 (`-serial stdio` shows logs in QEMU)
- Panic handler and basic boot banner
- Limine ISO build script and QEMU run script
- CI builds ISO and verifies boot log contains `RINT KERNEL: init OK`

## Prereqs (WSL2 Ubuntu 22)
```bash
sudo apt-get update
sudo apt-get install -y build-essential qemu-system-x86 xorriso make nasm gcc
```

## Build & Run (Locally)
```bash
bash scripts/make_iso.sh
bash scripts/qemu.sh
```

Expected output:
```
==============================
 RINT Rust Microkernel (M1) 
 Arch: x86_64 | Boot: Limine(stivale2) | License: Apache-2.0 
==============================
RINT KERNEL: init OK
```

## Roadmap — M1
See [docs/m1-roadmap.md](docs/m1-roadmap.md).

## Next steps
- Set up GDT, IDT, and interrupt handlers
- Initialize paging & a basic physical page allocator
- Timer interrupt (PIT/APIC) for preemption
- Thread control blocks and round-robin scheduler
- IPC channels and syscall stubs
- Userland loader (ELF or simple image) and a tiny demo program
