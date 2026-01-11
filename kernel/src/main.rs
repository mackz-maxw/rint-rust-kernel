#![no_std]
#![no_main]

use core::arch::global_asm;

// Define a minimal stivale2 header so Limine can find our entry point and stack.
// Entry: kstart (defined in lib.rs), Stack: temporary bootstrap stack.
global_asm!(
r#"
    .section .stivale2hdr, "a"
    .global stivale2_hdr
stivale2_hdr:
    .quad kstart        # entry point
    .quad stack_top     # stack pointer
    .quad 0             # flags
    .quad 0             # tags (none)

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