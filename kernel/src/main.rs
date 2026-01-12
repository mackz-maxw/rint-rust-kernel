#![no_std]
#![no_main]

use core::arch::global_asm;

// Minimal bootstrap: set a temporary stack and call kstart() defined in lib.rs.
// Limine loads the kernel in long mode; we rely on its environment.
global_asm!(
r#"
    .section .text._start
    .global _start
_start:
    leaq stack_top(%rip), %rsp
    call kstart

1:  hlt
    jmp 1b

    .section .bss
    .align 16
    .global __bootstrap_stack
__bootstrap_stack:
    .space 0x8000

    .global stack_top
stack_top:
    .quad __bootstrap_stack + 0x8000
"#
);