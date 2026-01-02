#![no_std]

use hal::prelude::*;
use crate::{TaskMeta, TaskClass};
use metrics::Recorder;

pub struct JointConfig<'a> {
    pub rr_timeslice_ms: u64,
    pub cpu_bound_threshold_ema: f32,
    pub reclass_hysteresis_ms: u64,
    pub wfq_weights: &'a [u32],
    pub edf_default_deadline_ms: u64,
}

pub struct JointScheduler<'a, T: Timer, I: IrqCtl, C: ContextSwitch> {
    cfg: JointConfig<'a>,
    hal: &'a Hal<'a, T, I, C>,
    rec: &'a mut Recorder,
    // 简化队列与任务集合（占位）
    tasks: heapless::Vec<TaskMeta, 64>,
    ema_alpha: f32,
    last_reclass_ms: u64,
}

impl<'a, T: Timer, I: IrqCtl, C: ContextSwitch> JointScheduler<'a, T, I, C> {
    pub fn new(cfg: JointConfig<'a>, hal: &'a Hal<'a, T, I, C>, rec: &'a mut Recorder) -> Self {
        Self {
            cfg,
            hal,
            rec,
            tasks: heapless::Vec::new(),
            ema_alpha: 0.4,
            last_reclass_ms: 0,
        }
    }

    pub fn spawn_demo_tasks(&mut self) {
        let _ = self.tasks.push(TaskMeta {
            id: 1, recent_cpu_burst_ms: 3.0, class: TaskClass::LatencySensitive,
            deadline_ms: Some(self.cfg.edf_default_deadline_ms), weight: 2,
        });
        let _ = self.tasks.push(TaskMeta {
            id: 2, recent_cpu_burst_ms: 15.0, class: TaskClass::CpuBound,
            deadline_ms: None, weight: 1,
        });
    }

    pub fn tick(&mut self) {
        let now = self.hal.timer.now_ms();
        // 定期再分类，避免频繁抖动
        if now - self.last_reclass_ms > self.cfg.reclass_hysteresis_ms {
            self.reclassify();
            self.last_reclass_ms = now;
        }
        // 选择下一个任务（联合策略）
        if let Some(next) = self.pick_next(now) {
            self.rec.on_schedule(next.id, now);
            // 上下文切换占位
            // self.hal.ctx.switch_to(&handle);
            // 时间片控制（RR）
            self.hal.timer.schedule_tick_in(self.cfg.rr_timeslice_ms);
        }
    }

    fn reclassify(&mut self) {
        for t in self.tasks.iter_mut() {
            // EMA 更新（示例）
            let ema = self.ema_alpha * t.recent_cpu_burst_ms + (1.0 - self.ema_alpha) * t.recent_cpu_burst_ms;
            t.recent_cpu_burst_ms = ema;
            t.class = if ema >= self.cfg.cpu_bound_threshold_ema {
                TaskClass::CpuBound
            } else {
                TaskClass::LatencySensitive
            };
            // 可以记录事件
            // self.rec.on_reclass(t.id, t.class);
        }
    }

    fn pick_next(&self, now_ms: u64) -> Option<TaskMeta> {
        // 简化：优先选择有 deadline 的任务（EDF），否则 RR/WFQ
        let mut edf: Option<TaskMeta> = None;
        for t in self.tasks.iter() {
            if let Some(deadline) = t.deadline_ms {
                if edf.map_or(true, |cur| deadline < cur.deadline_ms.unwrap_or(u64::MAX)) {
                    edf = Some(*t);
                }
            }
        }
        if edf.is_some() {
            return edf;
        }
        // RR/WFQ 占位：根据 weight 进行加权轮转，示例简单返回第一个
        self.tasks.first().copied()
    }
}