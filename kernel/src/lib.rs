#![no_std]
#![no_main]
// #![feature(asm_const)] 

use core::fmt::Write;
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

#[unsafe(no_mangle)]
extern "C" fn kstart() -> ! {
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

#[doc(hidden)]
pub fn kprint(args: core::fmt::Arguments) {
    let mut lock = SERIAL1.lock();
    if let Some(sp) = lock.as_mut() {
        let _ = sp.write_fmt(args);
        let _ = sp.write_str("\n");
    }
}

#[macro_export]
macro_rules! kprintln {
    ($($arg:tt)*) => {
        $crate::kprint(core::format_args!($($arg)*))
    };
}