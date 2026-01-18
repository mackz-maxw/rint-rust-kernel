#![no_std]
#![no_main]
// #![feature(asm_const)] 

use core::fmt::Write;
use core::ptr;
use spin::Mutex;
use uart_16550::SerialPort;
use x86_64::instructions::{hlt, interrupts};

static SERIAL1: Mutex<Option<SerialPort>> = Mutex::new(None);

#[cfg(not(test))]
#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    kprintln!("PANIC: {info}");
    loop {
        hlt();
    }
}

#[unsafe(no_mangle)] // 禁止编译器对该函数进行名称改编，确保最终 ELF 里的符号名就是 kstart
pub extern "C" fn kstart() -> ! {
    init_serial();
    banner();

    // TODO: IDT/GDT setup, paging init, timer init, scheduler boot
    kprintln!("RINT KERNEL: init OK");
    kprintln!("Hint: This is an M1 scaffold. Limine will load this ELF, and QEMU -serial stdio shows logs.");

    // Disable interrupts until we set IDT
    interrupts::disable();

    loop {
        hlt();
    }
}

fn init_serial() {
    let mut lock = SERIAL1.lock();
    if lock.is_none() {
        // Standard PC COM1 base port
        let mut sp = unsafe { SerialPort::new(0x3F8) };
        sp.init();
        *lock = Some(sp);
    }
}

fn banner() {
    kprintln!("==============================");
    kprintln!(" RINT Rust Microkernel (M1) ");
    kprintln!(" Arch: x86_64 | Boot: Limine | License: Apache-2.0 ");
    kprintln!("==============================");
}

#[doc(hidden)] //在生成文档（rustdoc）时不出现在公开 API 文档里，表示它是内部实现，用户应通过宏 kprintln! 间接调用
pub fn kprint(args: core::fmt::Arguments) { // 生成一个封装好的格式化参数对象
    let mut lock = SERIAL1.lock();
    if let Some(sp) = lock.as_mut() {
        let _ = sp.write_fmt(args);
        let _ = sp.write_str("\n");
    }
}

// --- Minimal C ABI shims ---
// These satisfy symbols the core/alloc runtime expects when no libc is present.
#[unsafe(no_mangle)]
pub extern "C" fn memcpy(dest: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    unsafe{ptr::copy_nonoverlapping(src, dest, n);}
    dest
}

#[unsafe(no_mangle)]
pub extern "C" fn memmove(dest: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    unsafe { ptr::copy(src, dest, n); }
    dest
}

#[unsafe(no_mangle)]
pub extern "C" fn memset(dest: *mut u8, value: i32, n: usize) -> *mut u8 {
    unsafe { ptr::write_bytes(dest, value as u8, n); }
    dest
}

#[unsafe(no_mangle)]
pub extern "C" fn memcmp(a: *const u8, b: *const u8, n: usize) -> i32 {
    for i in 0..n {
        let va = unsafe { *a.add(i) };
        let vb = unsafe { *b.add(i) };
        if va != vb {
            return va as i32 - vb as i32;
        }
    }
    0
}

#[macro_export]
macro_rules! kprintln {
    // 接受任意格式化参数列表，等同 println! 的可变参数匹配方式
    ($($arg:tt)*) => { // $arg:tt：匹配任意“token tree”片段；$( … )*：表示重复零次或多次
        $crate::kprint(core::format_args!($($arg)*))
    };
}