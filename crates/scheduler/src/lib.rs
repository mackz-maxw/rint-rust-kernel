#![no_std]

pub mod joint;

#[derive(Clone, Copy, Debug)]
pub enum TaskClass {
    CpuBound,
    LatencySensitive,
}

#[derive(Clone, Copy, Debug)]
pub struct TaskMeta {
    pub id: u64,
    pub recent_cpu_burst_ms: f32,
    pub class: TaskClass,
    pub deadline_ms: Option<u64>,
    pub weight: u32,
}