# Benchmarking dry-validation-rust

The repository has three benchmark layers with deliberately different jobs.
Do not use a result from one layer as if it came from another.

## 1. Interactive showcase

Use `benchmark/schema_throughput.rb` in text mode when exploring a change or
capturing a human-readable comparison:

```bash
IPS_WARMUP=3 IPS_TIME=10 MEMORY_PROFILE_N=5000 \
  SCENARIO=large_form ruby -Ilib benchmark/schema_throughput.rb
```

Text mode uses `Benchmark.ips` for warmed throughput, `MemoryProfiler` for Ruby
allocation detail, and the fixed-run path for peak RSS. It is useful for local
inspection and screenshots. A single text run is not canonical release/CV
evidence.

## 2. Publication evidence

Use the publication runner for README, release notes, external posts, or CV
numbers:

```bash
bundle exec rake compile
bundle exec script/benchmark-publication
```

Defaults:

- 5 independent runs per engine/scenario;
- approximately 5 seconds of measured work per engine/run after calibration;
- 110 measurements (about 9 minutes of measured work) for the default 11-scenario,
  two-engine matrix, plus calibration, warmups, and process startup;
- a fresh Ruby process for every engine/scenario/run;
- engine-specific calibrated iteration counts so both sides receive a meaningful measurement duration;
- alternating Rust/upstream order between runs;
- reversed scenario order every other run to spread host drift;
- 500 sampled latency calls per measurement;
- no automatic outlier deletion;
- up to 2 retries for execution failures only;
- a checkpoint after calibration and after every successful measurement;
- live calibration and measurement progress on stderr;
- refusal to publish from a dirty working tree by default.

The runner writes JSON and Markdown under `tmp/benchmarks/`, which is already
ignored by Git. The JSON records the exact commit SHA, dirty state, Ruby,
platform, CPU, YJIT state, Rust toolchain, protocol, calibration values, every
raw measurement, and aggregate statistics.

If a run is interrupted, use the checkpoint path printed at startup:

```bash
RESUME_FROM=tmp/benchmarks/publication-...checkpoint.json \
  bundle exec script/benchmark-publication
```

A checkpoint can only be resumed with the same protocol and Git commit.

The comparison defaults to `dry-validation 1.11.1`. Override it explicitly only when you intend to change the baseline; the actual loaded `dry-validation`, `dry-schema`, and `dry-types` versions are recorded in the raw results.

Useful overrides:

```bash
# Stronger/longer publication run
RUNS=7 TARGET_SECONDS=10 bundle exec script/benchmark-publication

# Compare against another explicitly chosen upstream version
UPSTREAM_VERSION=1.11.1 bundle exec script/benchmark-publication

# One scenario only
SCENARIO=array_of_objects bundle exec script/benchmark-publication

# Strict-key variant
VALIDATE_KEYS=true SCENARIO=large_form bundle exec script/benchmark-publication

# Exploratory run from uncommitted code (never use as canonical evidence)
ALLOW_DIRTY=true bundle exec script/benchmark-publication

# Retry an execution failure up to 4 times
RETRIES=4 bundle exec script/benchmark-publication
```

### Why publication mode calibrates first

A single fixed `N` is too short for fast scenarios and unnecessarily long for
heavy scenarios. Publication mode measures each engine briefly, chooses an
iteration count intended to provide roughly `TARGET_SECONDS` of measured work
for that engine, and then keeps those calibrated counts fixed across repetitions. Calibration is only used to
choose `N`; calibration measurements never become published results.

### Variability policy

Every successful run remains in the JSON. The summary reports median, range,
median absolute deviation (MAD), and spread. Slow or inconvenient runs are not
silently rerun or removed. Wide ranges/high MAD are a reason to investigate the
host and rerun the full protocol, not a reason to cherry-pick a better value.

Retries are for process/tooling failures (for example a crashed child process),
not for performance outliers.

## 3. CI regression detection

CI regression gates answer a different question: "did this change regress a
known benchmark on the CI host?" They are not a source for cross-machine
absolute speed claims. Keep using the existing latency/allocation gates for
change detection.

## Scenario matrix

The original six scenarios remain unchanged, and five additional scenarios add
shapes that were previously missing.

| Scenario | Purpose |
| --- | --- |
| `small_form` | 5-field valid scalar baseline |
| `medium_form` | 25 fields, 80% valid calls |
| `large_form` | 100 fields, 50/50 valid/invalid calls |
| `nested_object` | deep 10-level traversal |
| `array_of_objects` | 100 nested objects with 5 fields each |
| `all_invalid` | error-heavy 20-field payload |
| `sparse_optional` | 50 optional fields with only 20% present; missing-key cost |
| `mixed_types` | integer/float/bool/string coercion in one request |
| `array_of_primitives` | 500 coercible integer members without nested hashes |
| `wide_nested_object` | breadth: 10 sibling hashes × 10 fields |
| `ruby_rules` | native schema work plus Ruby-owned dynamic rule execution |

`ruby_rules` is intentionally included even if it lowers the Rust-vs-upstream
ratio. The project explicitly preserves dynamic Ruby domain rules, so a matrix
that benchmarks only native-friendly schema work would overstate the hybrid
approach for real contracts.

## Metrics and wording

### Throughput

For public claims, prefer the median paired speedup and include the observed
range. Example wording:

> On this host and benchmark matrix, median validation throughput ranged from
> X× to Y× versus dry-validation 1.11.1.

Do not turn a validation-only ratio into a Rails request speedup claim.

### Ruby allocations

`ruby_allocated_objects_per_call` comes from `GC.stat`. `MemoryProfiler` in the
interactive report also observes Ruby allocations. Neither measures total Rust
heap allocation. Say "Ruby-side allocations" rather than "total memory".

### Peak RSS

Peak RSS is whole-process high-water memory, not per-validation memory. It is
useful as a process-level signal but can be influenced by runtime/library
loading and host behavior. Compare only isolated runs from the same protocol.

### Latency

p50/p95/p99 are sampled call latencies after warmup. Use p95/p99 for tail
behavior and CI regression checks; do not infer request-level latency without a
request-level benchmark.

## Before publishing numbers

Use a committed clean checkout, keep the machine on the same power/performance
mode, close unrelated heavy workloads, and record results from the publication
runner. Review every scenario, including regressions. If variability is large,
repeat the full run rather than selecting a favorable subset.

The README should state the date, exact Git SHA, runtime/toolchain, host CPU/OS,
upstream version, protocol settings, and that the figures are host/workload
specific. CV wording should use a range supported by the stable scenarios, not
the single best observed row.
