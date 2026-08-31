# dry-validation-rust

`dry-validation-rust` is a performance-oriented hybrid Ruby/Rust validation
engine with familiar dry-validation-style contract syntax and a precisely
documented compatible subset. Rust handles the immutable declarative schema
execution path; Ruby preserves dynamic rules and Ruby-specific semantics.

> Note: This is an early-stage project. The side-by-side API is covered by
> focused tests, differential checks, package verification, and reproducible
> benchmark evidence, but it is not a full, production-ready drop-in
> replacement for upstream `dry-validation`.

Before adoption, review [the support matrix](docs/SUPPORT_MATRIX.md),
[compatibility matrix](docs/COMPATIBILITY.md), and
[verification evidence](docs/VERIFICATION.md) for the exact supported surface,
platforms, and known boundaries.

New users can follow the [Getting started guide](docs/getting-started.md) to
install the gem and build their first contract.

The native extension's [Rust API reference](https://alex-tomilov.github.io/dry-validation-rust/rustdoc/)
is published with the documentation site.

For project participation and reporting routes, see
[CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md),
[SECURITY.md](SECURITY.md), [GOVERNANCE.md](GOVERNANCE.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md).
See the concise [roadmap](docs/ROADMAP.md) for planned outcomes and
[project-management policy](docs/PROJECT_MANAGEMENT.md) for issue workflow.

## What this project is

- Rust owns the immutable schema plan, key lookup and normalization, nested
  traversal, built-in coercion, type checks, native predicates, output
  filtering, and structural error collection.
- Ruby owns class-level DSL capture, arbitrary rule blocks, injected Ruby
  objects, macros, custom behavior, and Ruby-specific predicate semantics.

Rewriting arbitrary Ruby blocks into Rust is neither generally possible nor
desirable. Calling those blocks through Ruby preserves the feature that makes
`dry-validation` useful: domain validation can be normal Ruby.

## What this project is not

- It is not a proven drop-in replacement for upstream `dry-validation`.
- It is not a full Rust rewrite of the dry-rb validation stack.
- It does not claim full upstream compatibility without fixture-backed,
  version-pinned differential evidence.
- It does not claim general speedups without representative benchmarks.

## Installation

When a precompiled gem is published for your platform, install it with:

```bash
gem install dry-validation-rust
```

See the [support matrix](docs/SUPPORT_MATRIX.md) for the authoritative version
and platform status. If a source build is required, see the
[source-build instructions](docs/getting-started.md#build-from-source).

## Primary safe API

For new work, use `require "dry/validation/rust"` and subclass
`Dry::Validation::Rust::Contract`. The [Getting started guide](docs/getting-started.md)
has a copy-pasteable contract, rule, error-handling, and web-framework examples.

Version, platform, and upstream-reference targets are listed in
[SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md). Supported DSL and semantic
differences are listed in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

### Side-by-side API stability

The public side-by-side API is `Dry::Validation::Rust::Contract`, its nested
`Result` and `Values` types, and the directly exposed `Schema`, `MessageSet`,
and `Evaluator` types. Its compatibility policy is defined in the
[support matrix](docs/SUPPORT_MATRIX.md), with individual classifications in
[API_STABILITY.md](docs/API_STABILITY.md). The exact-compatibility entrypoints
are explicitly experimental and are not covered by that policy.

## Loading

`require "dry/validation/rust"` exposes only the
`Dry::Validation::Rust` namespace. It does not define
`Dry::Validation::Contract` or `Dry::Schema`.

The upstream-like `require "dry/validation"` and `require "dry/schema"`
entrypoints are deprecated and cannot safely coexist with upstream
`dry-validation` or `dry-schema` in one Ruby process. Use side-by-side mode for
new work; existing applications should follow the
[exact-mode migration guide](docs/MIGRATION_FROM_EXACT_MODE.md).

## Supported highlights

This section is a summary. Version and platform support is authoritative in
[SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md); feature support is authoritative
in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

- `params`, `json`, and plain `schema` modes.
- String-key normalization for Params and JSON.
- Integer, float, decimal, boolean, symbol, Date, DateTime, and Time Params
  coercions.
- Required/optional keys, `filled`, `maybe`, hashes, arrays, primitive array
  members, and arrays of nested hashes.
- Numeric and size predicates in Rust; format, inclusion, exclusion, and Ruby
  equality predicates in Ruby for semantic fidelity.
- Ordered rules that run only when their schema dependencies succeeded.
- Symbol, dot-string, array, and simple hash rule paths.
- `value`, `values`, `key?`, `key.failure`, `key(path).failure`,
  `base.failure`, `schema_error?`, `rule_error?`, and
  `base_rule_error?`.
- `rule.each` with `index:`.
- Global and class macros, macro arguments, injected `option` values, and
  mutable per-call context.
- Result hashes, message sets, metadata, full messages, filtering, and Ruby
  pattern matching.
- Contract inheritance and compatible schema reuse.

The complete exclusions and semantic differences are explicit in
[COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Building from source

Meet the [source-build prerequisites](docs/getting-started.md#build-from-source)
first.

Then:

```bash
bundle install
bundle exec rake compile
bundle exec rake test
```

The source gem declares `rb_sys ~> 0.9` and builds through the ordinary Ruby
native-extension lifecycle.

## Verification

Representative verification evidence, including its pinned runtime versions,
is recorded in [VERIFICATION.md](docs/VERIFICATION.md).

The test suite covers the native plan, coercion modes, nested data, rules,
rule skipping, array rules, macros, options, context, inheritance, external
schemas, loading modes, pattern matching, metadata, concurrent calls, malformed
input resilience, package contents, and differential compatibility fixtures.

## Benchmarking

The validation benchmark system has three deliberately separate jobs:

1. an interactive `Benchmark.ips`/`MemoryProfiler` showcase for local
   exploration and screenshots;
2. a repeatable publication runner for README, release, post, and CV evidence;
3. CI regression gates for detecting performance changes on CI hosts.

The detailed protocol and metric wording are documented in
[`docs/BENCHMARKING.md`](docs/BENCHMARKING.md).

### Interactive comparison

Run the representative matrix directly when exploring a change:

```bash
ruby -Ilib benchmark/schema_throughput.rb
ENGINE=rust SCENARIO=medium_form ruby -Ilib benchmark/schema_throughput.rb
ENGINE=upstream SCENARIO=nested_object ruby -Ilib benchmark/schema_throughput.rb
IPS_WARMUP=3 IPS_TIME=10 MEMORY_PROFILE_N=5000 \
  SCENARIO=array_of_objects ruby -Ilib benchmark/schema_throughput.rb
```

Text output uses `Benchmark.ips` for warmed throughput, `MemoryProfiler` for
Ruby-side allocation detail, and the fixed-run path for peak RSS. A single text
run is useful evidence while developing, but it is not the canonical source for
README/CV performance claims.

The matrix currently covers eleven validation shapes: small, medium, and large
flat forms; deep nesting; arrays of nested objects; an all-invalid error path;
sparse optional data; mixed scalar coercions; a large primitive array; wide
nested data; and a contract that combines declarative schema work with
Ruby-owned dynamic rules.

### Publication-quality evidence

Use the publication runner before updating benchmark claims:

```bash
bundle exec rake compile
bundle exec script/benchmark-publication
```

By default it performs five independent measurements per engine/scenario. It
first calibrates the iteration count for each scenario, then runs each engine in
a fresh Ruby process using an engine-specific calibrated `N`, so a faster engine
is not accidentally measured for a much shorter interval. Engine order alternates
between runs and scenario order reverses every other run to reduce systematic
host drift. Successful results are never discarded automatically. The full
default matrix has 110 measurements, so it performs about 9 minutes of measured
work before calibration, warmups, and process startup; the runner reports live
calibration and measurement progress to stderr.

The runner records the exact Git SHA and dirty state, Ruby/platform/CPU details,
YJIT state, Rust toolchain, requested and actually loaded upstream gem versions,
protocol settings, every raw measurement, medians,
ranges, median absolute deviation, paired throughput ratios, Ruby allocation
changes, and peak RSS changes.

Results and checkpoints are written under `tmp/benchmarks/` (already ignored by
Git). If a run is interrupted, resume it from the printed checkpoint path:

```bash
RESUME_FROM=tmp/benchmarks/publication-...checkpoint.json \
  bundle exec script/benchmark-publication
```

For a longer final evidence run:

```bash
RUNS=7 TARGET_SECONDS=10 bundle exec script/benchmark-publication
```

`RETRIES` applies only to process/tooling failures. The runner does not retry a
successful measurement merely because it is slow or weakens the speedup claim.
Publication mode refuses a dirty working tree unless `ALLOW_DIRTY=true` is set;
dirty runs are exploratory and should not become canonical README/CV evidence.

Use `FORMAT=json` on the lower-level benchmark only when tooling needs one
single fixed-run payload:

```bash
FORMAT=json ENGINE=all SCENARIO=small_form \
  N=10000 WARMUP=1000 LATENCY_SAMPLES=500 \
  ruby -Ilib benchmark/schema_throughput.rb
```

### Process-memory evidence

Ruby allocation counters are useful for understanding GC pressure, but an
allocated-object count is not a whole-process memory measurement. For a
same-work comparison of the hybrid and upstream implementations, run:

```bash
bundle exec rake compile
bundle exec script/benchmark-memory-footprint
```

The memory runner uses the same validation count and warmup for both engines in
each scenario. On Linux it records current/peak RSS plus PSS and USS around the
timed validation loop. Peak RSS includes resident Ruby and Rust/native memory;
PSS apportions shared pages and USS reports private resident pages. See
[`docs/MEMORY_BENCHMARKING.md`](docs/MEMORY_BENCHMARKING.md) for exact metric
semantics and limitations.

These are process-footprint metrics, not cumulative bytes allocated over time.
Ruby object counts from `GC.stat` remain a separate GC-pressure signal.

Ruby allocation counters (`GC.stat` and the interactive `MemoryProfiler`
section) describe Ruby-side allocation activity. Peak RSS is a whole-process
resident high-water mark and already includes resident Ruby and Rust/native
memory, but it is not cumulative allocated bytes and it fully counts shared
resident pages. Use the separate process-memory runner for same-work RSS/PSS/USS
comparisons. Throughput ratios apply to validation calls after contract/plan
construction and must not be presented as end-to-end Rails request speedups.

Refresh the allocation-regression baseline only after intentionally reviewing
an allocation change:

```bash
bundle exec script/record-allocation-baseline
```

The manual **Record Allocation Baseline** workflow produces the same JSON as an
artifact without changing the repository. Review its value before replacing
`benchmark/baseline_allocations.json`; do not accept an allocation regression
merely by refreshing the baseline.

The upstream `dry-validation` gem remains intentionally outside the project
dependencies. Install the comparison version for the same Ruby before running
comparison/publication benchmarks. Report the exact upstream version with every
published result.

### Plan-compilation benchmark

Measure native JSON plan deserialization independently of validation calls:

```bash
cargo bench --locked --manifest-path ext/dry_validation_rust/Cargo.toml --bench plan_compile
```

CI runs this non-blocking benchmark on Ubuntu and retains the combined
Criterion reports as the `native-benchmarks` artifact for 30 days. On
2026-08-14, the
following 100-sample Criterion results were measured locally on x86_64 Linux
(kernel 7.0.0-29-generic, AMD Ryzen 7 5800H) with Rust 1.90.0. Each generated
Params-mode plan has `validate_keys` enabled; every field is a required string
with one `min_size(1)` predicate. These figures are local baseline evidence,
not a cross-host performance guarantee.

| Plan size  | Criterion estimate (95% confidence interval) | Point estimate |
| ---------- | -------------------------------------------: | -------------: |
| 5 fields   |                             1.8861–1.8954 µs |      1.8905 µs |
| 50 fields  |                             20.520–20.686 µs |      20.604 µs |
| 200 fields |                             83.591–87.909 µs |      85.538 µs |

### Coercion benchmark

Measure the native Params-mode coercion path independently for common and
Ruby-fallback literals:

```bash
cargo bench --locked --manifest-path ext/dry_validation_rust/Cargo.toml --bench coercion
```

CI runs the plan-compilation and coercion benchmarks non-blockingly on Ubuntu
and retains their combined Criterion reports as the `native-benchmarks`
artifact for 30 days.

The following coercion results were measured locally on 2026-08-14 with CRuby
3.4.4, Rust 1.90.0, and `dry-validation-rust` 0.1.0.pre4 on x86_64 Linux
(kernel 7.0.0-29-generic, AMD Ryzen 7 5800H). Criterion used 100 samples with
a 500 ms warm-up and 1 s measurement period per case. These are host-local
baseline observations, not cross-host performance guarantees. `Infinity` exercises the intentional
non-finite-float rejection path; the datetime-shaped date literal exercises the Ruby fallback path.

| Group             | Input                  | Criterion estimate (95% confidence interval) | Point estimate |
| ----------------- | ---------------------- | -------------------------------------------: | -------------: |
| Integer           | `42`                   |                             119.60–126.54 ns |      122.99 ns |
| Integer           | `-99`                  |                             116.84–120.98 ns |      118.79 ns |
| Integer           | `1_000`                |                             129.17–135.89 ns |      132.29 ns |
| Integer           | `0xFF`                 |                             119.38–124.78 ns |      121.89 ns |
| Float             | `3.14`                 |                             131.74–133.14 ns |      132.40 ns |
| Float             | `-2.5e10`              |                             180.62–181.84 ns |      181.17 ns |
| Float (rejection) | `Infinity`             |                             83.982–84.862 ns |      84.402 ns |
| Boolean           | `true`                 |                             80.455–83.671 ns |      81.937 ns |
| Boolean           | `false`                |                             81.399–86.340 ns |      83.778 ns |
| Boolean           | `1`                    |                             123.77–132.78 ns |      128.38 ns |
| Boolean           | `0`                    |                             132.99–153.74 ns |      143.02 ns |
| Boolean           | `yes`                  |                             99.111–102.16 ns |      100.53 ns |
| Boolean           | `no`                   |                             99.193–100.15 ns |      99.620 ns |
| Date              | `2024-01-01`           |                             573.70–596.35 ns |      584.53 ns |
| Date (fallback)   | `2024-01-01T12:00:00Z` |                             2.7212–3.1991 µs |      2.9518 µs |
| Decimal           | `123.456`              |                             746.42–781.89 ns |      761.67 ns |
| Decimal           | `0.0000001`            |                             726.38–738.29 ns |      731.78 ns |

### Predicate benchmark

Measure the native comparison, size, and parity predicate paths with Ruby
values created once before timing:

```bash
cargo bench --locked --manifest-path ext/dry_validation_rust/Cargo.toml --bench predicates
```

CI runs the plan-compilation, coercion, and predicate benchmarks non-blockingly
on Ubuntu and retains their combined Criterion reports as the
`native-benchmarks` artifact for 30 days.

The following results were measured locally on 2026-08-15 with CRuby 3.4.4,
Rust 1.90.0, and `dry-validation-rust` 0.1.0.pre4 on x86_64 Linux (kernel
7.0.0-29-generic, AMD Ryzen 7 5800H). Criterion used 100 samples with a
500 ms warm-up and 1 s measurement period per case. Every input passes its
predicate; values and predicate plans are prepared before the timed loop.
These are host-local baseline observations, not cross-host performance
guarantees.

| Group      | Case              | Criterion estimate (95% confidence interval) | Point estimate |
| ---------- | ----------------- | -------------------------------------------: | -------------: |
| Comparison | `gt` integer      |                             8.5136–8.5606 ns |      8.5340 ns |
| Comparison | `gteq` integer    |                             8.6687–8.9753 ns |      8.7905 ns |
| Comparison | `lt` integer      |                             9.0641–9.5832 ns |      9.3130 ns |
| Comparison | `lteq` integer    |                             8.5890–8.6289 ns |      8.6062 ns |
| Comparison | `gt` float        |                             7.8649–7.9178 ns |      7.8890 ns |
| Comparison | `gteq` float      |                             7.8643–7.8929 ns |      7.8779 ns |
| Comparison | `lt` float        |                             7.8780–7.9643 ns |      7.9147 ns |
| Comparison | `lteq` float      |                             7.8838–8.6503 ns |      8.2060 ns |
| Size       | `size` string     |                             33.124–33.230 ns |      33.178 ns |
| Size       | `min_size` string |                             35.507–35.567 ns |      35.536 ns |
| Size       | `max_size` string |                             32.986–33.263 ns |      33.111 ns |
| Size       | `size` array      |                             10.187–10.252 ns |      10.216 ns |
| Size       | `min_size` array  |                             10.253–10.457 ns |      10.338 ns |
| Size       | `max_size` array  |                             10.160–10.352 ns |      10.228 ns |
| Size       | `size` hash       |                             10.763–10.849 ns |      10.799 ns |
| Size       | `min_size` hash   |                             11.384–11.968 ns |      11.639 ns |
| Size       | `max_size` hash   |                             11.270–11.804 ns |      11.496 ns |
| Parity     | `odd?` integer    |                             7.8135–7.9664 ns |      7.8716 ns |
| Parity     | `even?` integer   |                             8.1242–8.2117 ns |      8.1567 ns |

### Full-schema benchmark

Measure the native engine end-to-end with plans and Ruby Hash inputs prepared
before Criterion begins timing:

```bash
cargo bench --locked --manifest-path ext/dry_validation_rust/Cargo.toml --bench full_schema
```

The following results were measured locally on 2026-08-15 with CRuby 3.4.4,
Rust 1.90.0, and `dry-validation-rust` 0.1.0.pre4 on x86_64 Linux (kernel
7.0.0-29-generic, AMD Ryzen 7 5800H). Criterion used 100 samples with a
3-second warm-up and a 5-second measurement period per scenario. Plans and
inputs are built once; mixed-validity scenarios cycle their prebuilt inputs.
These figures measure `Engine::call` only, and are host-local baseline
evidence—not a comparison with the Ruby contract benchmark or a cross-host
performance guarantee.

| Scenario         | Criterion estimate (95% confidence interval) | Point estimate |
| ---------------- | -------------------------------------------: | -------------: |
| Small form       |                             3.9515–3.9641 µs |      3.9573 µs |
| Medium form      |                             29.051–29.235 µs |      29.141 µs |
| Large form       |                             190.63–191.64 µs |      191.12 µs |
| 10-level nested  |                             8.8245–9.1422 µs |      8.9877 µs |
| 100-object array |                             318.85–322.47 µs |      320.55 µs |
| 20-field invalid |                             63.480–64.437 µs |      63.953 µs |

## Representative publication results (2026-08-24)

The following publication runs compare the hybrid engine with
dry-validation 1.11.1 (dry-schema 1.16.0 and dry-types 1.9.1) on CRuby 3.3.7,
x86_64 Linux, and an AMD Ryzen 7 5800H. They are host-local evidence, not a
cross-host guarantee or an end-to-end Rails request benchmark.

The throughput run measured commit `e26bbb18e90f` in seven isolated Ruby
processes per engine and scenario, targeting 10 seconds each. It measures
validation calls after contract/plan construction; ranges show the full set of
successful measurements.

| `SCENARIO`            | Rust validations/s, median (range) | Upstream validations/s, median (range) | Median speedup (range) |
| --------------------- | ---------------------------------: | -------------------------------------: | ---------------------: |
| `small_form`          |           100,083 (84,791–101,865) |                 40,111 (36,933–41,111) |      2.50× (2.11–2.56) |
| `medium_form`         |             14,517 (13,099–14,657) |                    2,792 (2,439–2,921) |      5.14× (4.97–5.51) |
| `large_form`          |                2,140 (1,816–2,153) |                          307 (275–344) |      6.73× (6.24–7.36) |
| `nested_object`       |             56,291 (50,939–62,997) |                 19,402 (17,589–20,917) |      2.98× (2.90–3.15) |
| `array_of_objects`    |                4,411 (4,202–4,778) |                          800 (709–832) |      5.68× (5.33–5.93) |
| `all_invalid`         |                5,397 (5,057–5,625) |                          823 (762–887) |      6.44× (6.16–7.38) |
| `sparse_optional`     |             30,623 (29,528–32,315) |                    7,345 (7,073–8,073) |      4.12× (3.66–4.41) |
| `mixed_types`         |             38,408 (36,599–39,227) |                 15,420 (14,069–16,033) |      2.48× (2.45–2.69) |
| `array_of_primitives` |             16,656 (15,718–17,299) |                    3,220 (3,083–3,272) |      5.20× (4.80–5.32) |
| `wide_nested_object`  |                8,472 (7,993–8,802) |                    3,744 (3,440–4,002) |      2.26× (2.06–2.33) |
| `ruby_rules`          |             18,127 (16,774–19,774) |                    8,812 (8,487–9,239) |      2.09× (1.93–2.16) |

The separate process-memory run measured commit `0f2f46414bc9`, also with
seven runs and identical validation count/warmup for both engines within each
scenario. Peak RSS is a whole-process high-water mark during the loop; the
Linux-only PSS and USS measurements are taken after it. PSS apportions shared
pages and USS counts private resident pages.

| `SCENARIO`            | Peak RSS reduction |     PSS reduction |     USS reduction | Ruby object reduction |
| --------------------- | -----------------: | ----------------: | ----------------: | --------------------: |
| `small_form`          |  12.9% (12.6–13.2) | 14.8% (14.5–15.0) | 16.2% (15.8–16.4) |                -42.9% |
| `medium_form`         |  12.3% (12.2–12.7) | 14.6% (14.3–14.8) | 15.9% (15.6–16.1) |                 63.7% |
| `large_form`          |  11.2% (10.7–11.4) | 12.9% (12.2–13.1) | 14.1% (13.5–14.3) |                 74.9% |
| `nested_object`       |  13.1% (12.8–13.4) | 15.3% (15.0–15.6) | 16.7% (16.4–17.0) |                -13.3% |
| `array_of_objects`    |  13.0% (12.2–13.1) | 15.1% (14.4–15.4) | 16.4% (15.7–16.7) |                  3.6% |
| `all_invalid`         |     9.5% (9.0–9.9) | 10.8% (10.2–11.1) | 12.0% (11.4–12.2) |                 78.0% |
| `sparse_optional`     |  15.7% (15.6–16.1) | 18.7% (18.2–18.9) | 20.1% (19.7–20.4) |                 39.3% |
| `mixed_types`         |  16.0% (15.4–16.2) | 18.8% (18.5–19.1) | 20.2% (19.9–20.6) |                -74.3% |
| `array_of_primitives` |  12.9% (11.9–13.1) | 14.6% (13.4–14.8) | 15.7% (14.5–15.9) |                 -2.6% |
| `wide_nested_object`  |  14.8% (14.4–15.2) | 17.1% (16.8–17.7) | 18.5% (18.2–19.1) |               -179.6% |
| `ruby_rules`          |  11.4% (10.9–12.3) | 13.1% (12.5–14.2) | 14.4% (13.7–15.4) |                 34.2% |

Ruby object reduction is a `GC.stat` count, not a byte total; negative values
mean the hybrid path allocated more Ruby objects. None of RSS, PSS, or USS is a
measure of cumulative allocated bytes. Reproduce fresh evidence with the
publication runners above rather than extrapolating these host-local figures.

## Important performance caveat

The native engine currently reads and creates Ruby objects, so it runs under
the GVL. Rust reduces Ruby method dispatch and intermediate DSL execution; it
does not automatically make validation parallel.

A future batch API could copy supported values into Rust-owned memory and
release the GVL, but serialization/copy cost and Ruby object semantics make
that a separate feature—not a free property of using Rust.

## License and relationship to dry-rb

This code is MIT licensed and independent. `dry-validation` and its related
dry-rb projects are MIT licensed as well, which permits reimplementation and
derivative work subject to preserving required notices when source is copied.
See [NOTICE.md](NOTICE.md). The distinct gem name and explicit non-affiliation
are intentional.
