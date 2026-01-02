use std::time::{Duration, Instant};
use std::thread;
use rand::Rng;

#[derive(Clone, Copy, Debug)]
enum TaskClass { CpuBound, LatencySensitive }

#[derive(Clone, Debug)]
struct SimTask {
    id: u64,
    class: TaskClass,
    weight: u32,
    deadline_ms: Option<u64>,
    recent_cpu_burst_ms: f32,
}

fn main() {
    // 负载生成：创建混合任务
    let mut tasks = vec![];
    for i in 0..8 {
        tasks.push(SimTask {
            id: i,
            class: if i % 3 == 0 { TaskClass::LatencySensitive } else { TaskClass::CpuBound },
            weight: if i % 2 == 0 { 2 } else { 1 },
            deadline_ms: if i % 3 == 0 { Some(20) } else { None },
            recent_cpu_burst_ms: 5.0,
        });
    }

    // 负载系数（例如 150%）
    let overload_factor = 1.5;
    let begin = Instant::now();
    let mut rng = rand::thread_rng();

    // 简化模拟：周期性迭代并统计
    for epoch in 0..300 {
        let mut cpu_time_ms = 0.0;
        let mut response_acc_ms = 0.0;

        for t in tasks.iter_mut() {
            let exec_ms = match t.class {
                TaskClass::CpuBound => 3.0 * overload_factor,
                TaskClass::LatencySensitive => 1.5 * overload_factor,
            };
            cpu_time_ms += exec_ms;
            response_acc_ms += exec_ms + rng.gen_range(0.2..0.8);
            t.recent_cpu_burst_ms = 0.4 * t.recent_cpu_burst_ms + 0.6 * exec_ms as f32;
            t.class = if t.recent_cpu_burst_ms >= 2.5 {
                TaskClass::CpuBound
            } else {
                TaskClass::LatencySensitive
            };
        }

        if epoch % 30 == 0 {
            println!(
                "[epoch={}] cpu_time_ms={:.2}, avg_resp_ms={:.2}",
                epoch,
                cpu_time_ms,
                response_acc_ms / tasks.len() as f64
            );
        }

        thread::sleep(Duration::from_millis(10));
    }

    let elapsed = begin.elapsed();
    println!("Simulation finished in {:.2?}", elapsed);
}