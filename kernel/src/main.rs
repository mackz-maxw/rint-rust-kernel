#![no_std]
#![no_main]
#![allow(unused_extern_crates)]

extern crate rint_kernel;

use core::arch::global_asm;

// 以汇编形式把最小的临时栈嵌入到 ELF 中，从而让 Limine 找到入口并使用该栈
// 然后把控制权交给 Rust 中定义的 kstart
global_asm!(
r#"
    .section .text._start
    .global _start
_start:
    lea rsp, [rip + stack_top]
    call kstart

1:  hlt
    jmp 1b

    .section .bss.stack, "aw", @nobits
    .align 16
    .global __bootstrap_stack
__bootstrap_stack:
    .space 0x8000

    .global stack_top
stack_top:
"#
);