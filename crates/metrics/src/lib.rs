#![no_std]

pub struct Recorder {
    // 可扩展为环形缓冲、串口输出或共享内存
    last_event_ts: u64,
}

impl Recorder {
    pub fn new() -> Self { Self { last_event_ts: 0 } }

    pub fn on_schedule(&mut self, task_id: u64, ts_ms: u64) {
        self.last_event_ts = ts_ms;
        // TODO: 输出事件，格式化为 CSV/自定义二进制
        // e.g., serial_write(b"...")
        let _ = task_id;
    }

    pub fn on_reclass(&mut self, _task_id: u64, _class: crate::TaskClass) {
        // 记录分类变化事件
    }
}