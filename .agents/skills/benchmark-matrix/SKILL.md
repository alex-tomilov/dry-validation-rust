---
name: benchmark-matrix
description: Run and interpret dry-validation-rust validation benchmarks. Use for local performance exploration, Rust-vs-upstream comparison, regression analysis, or publication-quality README/CV benchmark evidence.
---

# Benchmark Matrix

Choose the benchmark layer based on the question.

For quick human inspection or screenshots, use the text showcase:

```bash
bundle exec rake compile
IPS_WARMUP=3 IPS_TIME=10 MEMORY_PROFILE_N=5000 \
  SCENARIO=small_form ruby -Ilib benchmark/schema_throughput.rb
```

For README, release, LinkedIn, or CV evidence, do not manually copy a single
showcase run. Use the publication runner:

```bash
bundle exec rake compile
bundle exec script/benchmark-publication
```

The publication runner performs five independent measurements per
engine/scenario by default, calibrates scenario iteration counts, uses fresh
Ruby processes, alternates engine order, reverses scenario order every other
run, checkpoints after every successful measurement, and never discards
outliers automatically. Execution failures may be retried; slow measurements
must remain in the evidence.

For stronger evidence, use:

```bash
RUNS=7 TARGET_SECONDS=10 bundle exec script/benchmark-publication
```

If interrupted, resume from the checkpoint printed by the runner:

```bash
RESUME_FROM=tmp/benchmarks/<checkpoint>.json \
  bundle exec script/benchmark-publication
```

Before interpreting results, identify whether the changed code runs during
contract compilation or during `contract.call`. The schema-throughput matrix
measures calls after compilation, so parser and plan-construction changes are
not directly measured.

Report the exact Git SHA/dirty state, Ruby and Rust versions, OS/kernel/CPU,
requested and loaded upstream dry-validation/dry-schema/dry-types versions,
YJIT state, upstream dry-validation version, protocol, per-scenario medians and
ranges, paired speedup, latency, Ruby allocations/call, and peak RSS. Treat
Ruby allocation metrics as Ruby-side allocations, not total native memory.

Compare like with like only. Report neutral and negative results. Never rerun a
successful measurement merely because it weakens the claimed speedup.

Update `README.md` only after reviewing the generated JSON and Markdown and
confirming variability is acceptable. Keep previous results clearly dated if
they remain in the README. Never refresh `benchmark/baseline_allocations.json`
unless the user explicitly asks to accept a reviewed allocation-baseline
change.

Finish by running focused behavioral checks for changed code and:

```bash
bundle exec ruby -Itest test/benchmark_scenarios_test.rb
bundle exec ruby -Itest test/benchmark_publication_test.rb
bundle exec rubocop
```
