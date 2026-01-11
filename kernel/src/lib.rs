#![no_std]
#![no_main]

use core::fmt::Write;
use spin::Mutex;
use uart_16550::SerialPort;
use x86_64::instructions::{hlt, interrupts};

static SERIAL1: Mutex<Option<SerialPort>> = Mutex::new(None);

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    kprintln!("PANIC: {info}");
    loop {
        hlt();
    }
}

#[no_mangle]
extern "C" fn kstart(_stivale2_struct: *const u8) -> ! {
    init_serial();
    banner();

    // TODO: IDT/GDT setup, paging init, timer init, scheduler boot
    kprintln!("RINT KERNEL: init OK");
    kprintln!("Hint: Limine (stivale2) boots this ELF; use -serial stdio to view logs.");

    // Disable interrupts until IDT is set up
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
    kprintln!(" Arch: x86_64 | Boot: Limine(stivale2) | License: Apache-2.0 ");
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