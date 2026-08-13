---
name: benchmark-matrix
description: Run and interpret the dry-validation-rust representative throughput and Ruby-allocation matrix. Use when asked to benchmark validation performance, compare the Rust path with upstream dry-validation, assess a change's speed or allocation effect, or refresh README benchmark evidence.
---

# Benchmark Matrix

Run the six default scenarios three times with the release extension compiled:

```bash
bundle exec rake compile
ENGINE=all N=1000 WARMUP=200 LATENCY_SAMPLES=200 FORMAT=json ruby -Ilib benchmark/schema_throughput.rb
```

Run the matrix command three separate times. Preserve each JSON result in the
conversation or a temporary location; do not add benchmark artifacts to the
repository.

Before interpreting results, identify whether the changed code runs during
contract compilation or during `contract.call`. The matrix measures calls after
compilation, so parser and plan-construction changes are not directly measured.

Report the Ruby version, OS/kernel, CPU, configuration, per-scenario throughput
median and range, latency medians, Ruby allocations/call, and peak RSS. Compare
like with like only. Do not attribute a difference to a change when host,
version, or workload differs, and report neutral or negative results.

Update `README.md` only when all three runs complete and the results are useful
representative evidence. State the date, host, versions, settings, scope, and
variability. Never refresh `benchmark/baseline_allocations.json` unless the user
explicitly asks to accept a reviewed allocation-baseline change.

Finish by running the focused behavioral checks for changed code. Run
`bundle exec rubocop` when Ruby, benchmark, tooling, or CI files changed.
