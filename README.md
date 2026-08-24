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

### Precompiled (recommended)

When a precompiled gem is published for your platform, install it with:

```bash
gem install dry-validation-rust
```

See the [support matrix](docs/SUPPORT_MATRIX.md) for the authoritative version
and platform status.

### From source

When no precompiled gem is available for your platform, install the source gem
with RubyGems. Source builds require:

- CRuby 3.3 or newer with development headers;
- Rust 1.75 or newer and Cargo (the MSRV, tested in CI);
- a C toolchain; and
- libclang for the `rb-sys` bindgen step.

On Linux, install `clang` and `libclang-dev`. On macOS, install Xcode Command
Line Tools and LLVM, then point bindgen to Homebrew's keg-only library:

```bash
brew install llvm
export LIBCLANG_PATH="$(brew --prefix llvm)/lib"
```

On Windows with RubyInstaller, use its DevKit's UCRT Clang package rather than
the standalone LLVM distribution; bindgen must use the same headers and C
runtime as Ruby:

```powershell
ridk exec pacman -S --needed mingw-w64-ucrt-x86_64-clang
$env:LIBCLANG_PATH = "$env:RI_DEVKIT\ucrt64\bin"
```

The extension automatically selects Rust's matching GNU toolchain when it is
built by a MinGW Ruby.

If setup fails, confirm that `cargo` and your C compiler are discoverable on
`PATH` and that `LIBCLANG_PATH` contains the `libclang` library before rerunning
the install. A source checkout pins Rust 1.75.0 automatically through
`rust-toolchain.toml`.

```bash
gem install dry-validation-rust --platform ruby
```

## Primary safe API

Use the side-by-side namespace first:

```ruby
require "dry/validation/rust"

class NewUserContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
    optional(:display_name).maybe(:string)

    required(:addresses).array(:hash) do
      required(:city).filled(:string)
      required(:postcode).filled(:string)
    end
  end

  rule(:age) do
    key.failure("must be at least 18") if value < 18
  end
end

result = NewUserContract.new.call(
  "email" => "jane@example.org",
  "age" => "17",
  "display_name" => "",
  "addresses" => [{"city" => "Astana", "postcode" => "010000"}]
)

result.to_h
result.success?
result.errors.to_h
```

This is the primary supported API. Version, platform, and upstream-reference
targets are listed in [SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md). Supported
DSL and semantic differences are listed in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

### Side-by-side API stability

The public side-by-side API is `Dry::Validation::Rust::Contract`, its nested
`Result` and `Values` types, and the directly exposed `Schema`, `MessageSet`,
and `Evaluator` types. Its compatibility policy is defined in the
[support matrix](docs/SUPPORT_MATRIX.md), with individual classifications in
[API_STABILITY.md](docs/API_STABILITY.md). The exact-compatibility entrypoints
are explicitly experimental and are not covered by that policy.

## Migration-compatible subset

The safe API intentionally keeps familiar contract syntax where that behavior
is implemented and covered. Use it for comparison work and gradual migration
without taking over upstream constants:

```ruby
require "dry/validation/rust"

class AgeContract < Dry::Validation::Rust::Contract
  params do
    required(:age).value(:integer)
  end
end
```

## Loading

`require "dry/validation/rust"` exposes only the
`Dry::Validation::Rust` namespace. It does not define
`Dry::Validation::Contract` or `Dry::Schema`.

### Deprecated exact compatibility mode

The upstream-like `require "dry/validation"` and `require "dry/schema"`
entrypoints remain available temporarily, but they are deprecated and are not
a supported migration target. They cannot safely coexist with upstream
`dry-validation` or `dry-schema` in one Ruby process because both own the same
require paths and constants. Use the side-by-side namespace for new work and
follow the [exact-mode migration guide](docs/MIGRATION_FROM_EXACT_MODE.md) for
existing applications. The removal release and timeline will be announced in a
separately scoped deprecation implementation.

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

Meet the [source-install prerequisites](#from-source) first.

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

## Historical representative benchmark results (pre4)

The table below is retained as historical evidence from 2026-08-13. It was
measured with the earlier fixed-`N` protocol (`N=1000`, `WARMUP=200`, three
runs) on CRuby 3.3.7 / x86_64 Linux / AMD Ryzen 7 5800H, comparing the then
current pre4 code with dry-validation 1.11.1. It should not be compared directly
with current `Benchmark.ips` showcase output or used as evidence for unreleased
`develop` code. Replace this table only after reviewing a clean-checkout
`script/benchmark-publication` run and recording its exact Git SHA and protocol.

| `SCENARIO`                     | Rust validations/s (range) | Upstream validations/s (range) | Throughput ratio |           Rust p50/p95/p99 |       Upstream p50/p95/p99 |
| ------------------------------ | -------------------------: | -----------------------------: | ---------------: | -------------------------: | -------------------------: |
| `small_form`                   |     71,433 (67,480–76,023) |         35,157 (32,095–36,674) |            2.03× |          12.9/17.5/63.9 µs |          27.6/36.2/91.8 µs |
| `medium_form`                  |      10,595 (9,783–11,012) |            2,605 (1,731–2,689) |            4.07× |        38.3/295.9/475.9 µs |    86.0/1,707.8/1,945.3 µs |
| `large_form`                   |        1,549 (1,475–1,654) |                  307 (209–331) |            5.04× |   955.9/1,298.0/2,117.3 µs | 5,440.0/6,719.5/7,119.9 µs |
| `nested_object`                |     48,723 (35,219–49,256) |         19,212 (12,892–19,990) |            2.54× |         19.5/29.5/216.5 µs |         51.5/77.1/397.1 µs |
| `array_of_objects`             |        1,951 (1,811–2,028) |                  781 (743–802) |            2.50× |       455.9/707.2/824.6 µs | 1,207.2/1,594.1/1,979.3 µs |
| `all_invalid`                  |        4,071 (3,560–4,088) |                  772 (730–837) |            5.28× |       218.5/420.6/611.6 µs | 1,209.3/1,582.9/1,918.4 µs |
| `large_form` (`validate_keys`) |            974 (970–1,022) |                  304 (303–304) |            3.21× | 1,621.4/2,118.8/2,345.3 µs | 5,432.8/6,300.7/7,223.7 µs |

| `SCENARIO`                     | Rust Ruby allocations/call | Upstream Ruby allocations/call | Rust peak RSS | Upstream peak RSS |
| ------------------------------ | -------------------------: | -----------------------------: | ------------: | ----------------: |
| `small_form`                   |                      81.01 |                          49.01 |      24.6 MiB |          29.5 MiB |
| `medium_form`                  |                     451.00 |                       1,116.80 |      25.4 MiB |          29.9 MiB |
| `large_form`                   |                   2,836.00 |                      10,286.00 |      25.6 MiB |          30.4 MiB |
| `nested_object`                |                     145.00 |                         113.00 |      25.8 MiB |          30.5 MiB |
| `array_of_objects`             |                   3,460.80 |                       1,713.60 |      25.8 MiB |          30.8 MiB |
| `all_invalid`                  |                     976.00 |                       4,063.00 |      25.8 MiB |          30.9 MiB |
| `large_form` (`validate_keys`) |                   2,835.01 |                      10,490.01 |      25.3 MiB |          30.4 MiB |

The Rust path had higher Ruby allocation counts for the small, nested, and array scenarios; this
benchmark does not establish a native-allocation total. It measures validation calls after plan
construction, so it does not isolate plan-deserialization changes. Peak RSS is process high-water
memory, not per-call memory. Reproduce an individual row with, for example:

```bash
N=1000 WARMUP=200 LATENCY_SAMPLES=200 ENGINE=all SCENARIO=large_form ruby -Ilib benchmark/schema_throughput.rb
```

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
