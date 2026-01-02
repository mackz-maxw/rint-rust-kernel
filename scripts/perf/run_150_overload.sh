#!/usr/bin/env bash
set -euo pipefail
echo "运行sched-sim,如果perf可用即用perf测量。"
cargo build -p sched-sim --release
if command -v perf >/dev/null 2>&1; then
  perf stat -d -r 5 -- ./target/release/sched-sim
else
  ./target/release/sched-sim
fi