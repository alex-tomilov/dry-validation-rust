---
name: dvr-benchmark-regression
description: Analyze dry-validation-rust benchmark regressions, noisy performance results, or ambiguous optimization outcomes. Trigger whenever a performance task slows another scenario, produces unstable results, or lacks clear evidence.
---

# Benchmark regression analysis

Analyze before editing:

- environment and dependency differences;
- sample count, warmup, order, and noise;
- median and dispersion;
- allocations;
- GC count/time;
- RSS;
- schema compilation versus call time;
- Ruby/Rust boundary-call count;
- semantic fallback frequency;
- target and non-target scenario changes.

Recommend one:

- keep;
- rework;
- revert;
- gather more evidence.

If reworking:

1. propose one minimal change;
2. preserve correctness and differential fixtures;
3. define the exact benchmark acceptance threshold;
4. rerun the full benchmark group, not only the winning microbenchmark.

Never claim universal speedups or hide scenarios where upstream is faster. Finish with `dvr-delivery-gate`.
