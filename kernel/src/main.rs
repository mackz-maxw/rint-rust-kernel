#![no_std]
#![no_main]

use core::panic::PanicInfo;
use hal::prelude::*;
use scheduler::joint::{JointScheduler, JointConfig};
use metrics::Recorder;

#[no_mangle]
pub extern "C" fn _start() -> ! {
    kernel_main()
}

fn kernel_main() -> ! {
    // 平台早期初始化（示例，真实由 arch 层提供）
    arch_init();

    // 初始化计时器/IRQ/HAL
    let hal = hal::global();

    // 初始化指标记录器（串口输出或内存环形缓冲）
    let mut rec = Recorder::new();

    // 联合调度器配置：时间片、阈值、EDF/WFQ 参数
    let cfg = JointConfig {
        rr_timeslice_ms: 4,
        cpu_bound_threshold_ema: 2.5,
        reclass_hysteresis_ms: 10,
        wfq_weights: &[1, 2], // 示例权重
        edf_default_deadline_ms: 20,
    };
    let mut sched = JointScheduler::new(cfg, &hal, &mut rec);

    // 注册内置任务（占位）
    sched.spawn_demo_tasks();

    // 主循环：驱动调度与事件采样
    loop {
        sched.tick();
    }
}

fn arch_init() {
    // 由 arch-* crate 实现：IDT/IRQ/SBI/Timer 初始化等
    // 这里为占位
}

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    // 输出 panic 信息到串口或显示器
    // 并尝试安全停机或进入调试循环
    let _ = info;
    loop {}
}