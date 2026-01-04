#![no_std] // 内核环境下不使用标准库

pub mod prelude {
    pub use crate::{Timer, IrqCtl, ContextSwitch, Hal};
}

pub trait Timer {
    fn now_ms(&self) -> u64;
    fn schedule_tick_in(&self, ms: u64);
}

// 中断控制接口
pub trait IrqCtl {
    fn enable_irq(&self, irq: u32);
    fn disable_irq(&self, irq: u32);
    fn ack_irq(&self, irq: u32);
}

pub trait ContextSwitch {
    type TaskHandle;

    fn switch_to(&self, next: &Self::TaskHandle);
    fn yield_current(&self);
}

pub struct Hal<'a, T: Timer, I: IrqCtl, C: ContextSwitch> {
    pub timer: &'a T,
    pub irq: &'a I,
    pub ctx: &'a C,
}

// 单例入口（示例，真实项目应由 arch 层装配）
pub fn global<'a>() -> Hal<'a, DummyTimer, DummyIrq, DummyCtx> {
    Hal {
        timer: &DummyTimer,
        irq: &DummyIrq,
        ctx: &DummyCtx,
    }
}

// 以下为占位实现，便于早期编译通过
pub struct DummyTimer;
impl Timer for DummyTimer {
    fn now_ms(&self) -> u64 { 0 }
    fn schedule_tick_in(&self, _ms: u64) {}
}

pub struct DummyIrq;
impl IrqCtl for DummyIrq {
    fn enable_irq(&self, _irq: u32) {}
    fn disable_irq(&self, _irq: u32) {}
    fn ack_irq(&self, _irq: u32) {}
}

pub struct DummyCtx;
impl ContextSwitch for DummyCtx {
    type TaskHandle = usize;
    fn switch_to(&self, _next: &Self::TaskHandle) {}
    fn yield_current(&self) {}
}