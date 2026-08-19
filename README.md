# dry-validation-rust

`dry-validation-rust` is a performance-oriented hybrid Ruby/Rust validation
engine with familiar dry-validation-style contract syntax and a precisely
documented compatible subset. Rust handles the immutable declarative schema
execution path; Ruby preserves dynamic rules and Ruby-specific semantics.

> Status: `0.1.0.pre5` alpha pre-release. The side-by-side API has a defined
> `0.1.x` compatibility promise and is covered by focused tests, differential
> checks, package verification, and reproducible benchmark evidence. It is not
> a full, production-ready drop-in replacement for upstream `dry-validation`.

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

The current `0.1.x` support target is source builds; see the
[support matrix](docs/SUPPORT_MATRIX.md) for the authoritative platform status.

### From source

When no precompiled gem is available for your platform, install the source gem
with RubyGems. Source builds require:

- CRuby 3.3 or newer with development headers;
- Rust 1.75 or newer and Cargo (the MSRV, tested in CI);
- a C toolchain; and
- libclang for the `rb-sys` bindgen step.

On Linux, install `clang` and `libclang-dev`. On macOS, install Xcode Command
Line Tools and LLVM (for example, `brew install llvm`). On Windows, install the
Visual Studio C++ Build Tools with a Windows SDK and LLVM (for example,
`choco install llvm`). If setup fails, confirm that `cargo`, your C compiler,
and `libclang` are discoverable on `PATH` before rerunning the install. A
source checkout pins Rust 1.75.0 automatically through `rust-toolchain.toml`.

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

For the `0.1.x` line, the public side-by-side API is
`Dry::Validation::Rust::Contract`, its nested `Result` and `Values` types, and
the directly exposed `Schema`, `MessageSet`, and `Evaluator` types. Their
documented public methods will not be removed or changed incompatibly in a patch
release; a breaking side-by-side API change requires the next minor release. The
exact-compatibility entrypoints are explicitly experimental and are not covered
by this promise.

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

## Exact compatibility shim

Exact compatibility mode keeps upstream-like require paths and constants:

```ruby
require "dry/validation"

class AgeContract < Dry::Validation::Contract
  params do
    required(:age).value(:integer)
  end
end
```

> Collision warning: exact compatibility mode is experimental and opt-in. Do
> not install or activate upstream `dry-validation` / `dry-schema` in the same
> process when using `require "dry/validation"` or `require "dry/schema"` from
> this gem. Both implementations own the same require paths and constants. This
> gem raises a clear `LoadError` when it can detect such a collision.

The exact shim currently lives in this gem. If maintaining the shim separately
becomes necessary, the intended product split is `dry-validation-rust` for the
safe namespace and `dry-validation-rust-compat` for the upstream-like require
paths. No split is planned for the `0.1.x` line without concrete maintenance
evidence.

## Loading modes

### Side-by-side mode

`require "dry/validation/rust"` exposes only the
`Dry::Validation::Rust` namespace. It does not define
`Dry::Validation::Contract` or `Dry::Schema`.

### Exact compatibility mode

`require "dry/validation"` defines:

- `Dry::Validation::Contract` and related result/message aliases;
- minimal `Dry::Schema.Params`, `Dry::Schema.JSON`, and
  `Dry::Schema.define` factories for reusable schemas.

The collision warning above applies to every exact-mode entrypoint.

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

Current release evidence was collected with:

- CRuby 3.3.7;
- Rust 1.97.0;
- Magnus 0.8.2;
- rb-sys 0.9.128;
- an optimized release profile.

The test suite covers the native plan, coercion modes, nested data, rules,
rule skipping, array rules, macros, options, context, inheritance, external
schemas, loading modes, pattern matching, metadata, concurrent calls, malformed
input resilience, package contents, and differential compatibility fixtures.

Run the representative benchmark matrix with:

```bash
ruby -Ilib benchmark/schema_throughput.rb
N=500000 ruby -Ilib benchmark/schema_throughput.rb
ENGINE=rust ruby -Ilib benchmark/schema_throughput.rb
ENGINE=upstream ruby -Ilib benchmark/schema_throughput.rb
SCENARIO=array_of_objects ENGINE=rust ruby -Ilib benchmark/schema_throughput.rb
VALIDATE_KEYS=true SCENARIO=large_form ENGINE=rust ruby -Ilib benchmark/schema_throughput.rb
```

The six fixed scenarios cover small (5-field), medium (25-field, 80% valid),
and large (100-field, 50% valid) forms; a 10-level nested object; 100 objects
with five fields each (90% valid); and a 20-field all-invalid case. Each result
includes validations/second, sampled p50/p95/p99 latency, Ruby allocations per
call, and peak process RSS under the sustained run. Use `FORMAT=json` for
machine-readable output, and tune `WARMUP`, `N`, and `LATENCY_SAMPLES` when
collecting evidence. Text output uses `benchmark-ips` with a 2-second warmup
and 5-second measurement by default; tune those with `IPS_WARMUP` and
`IPS_TIME`. Its MemoryProfiler allocation section profiles 1,000 validations
per engine by default; tune that independently with `MEMORY_PROFILE_N`.

Refresh the allocation-regression baseline only after intentionally reviewing an
allocation change:

```bash
bundle exec script/record-allocation-baseline
```

The manual **Record Allocation Baseline** workflow produces the same JSON as an
artifact without changing the repository. Review its value before replacing
`benchmark/baseline_allocations.json`; do not accept an allocation regression
merely by refreshing the baseline.

By default the benchmark compares this Rust-backed hybrid implementation with
the upstream `dry-validation` gem in a separate Ruby process. The upstream gem
is intentionally not a project dependency; install it for the same Ruby with
`gem install dry-validation` before running `ENGINE=all` or `ENGINE=upstream`.
The matrix is a reproducible measurement harness, not a published performance
claim: compare repeated runs on the same machine and report neutral or negative
results alongside favorable ones.

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
baseline observations, not cross-host performance guarantees. `Infinity` exercises the intentional non-finite-float rejection path; the datetime-shaped date literal exercises the Ruby fallback path.

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

## Representative benchmark results

The six default rows were measured on 2026-08-13 with CRuby 3.3.7 on x86_64 Linux (kernel 7.0.0-29-generic, AMD Ryzen 7 5800H), comparing dry-validation-rust 0.1.0.pre4 with dry-validation 1.11.1. The strict-key row remains the 2026-08-10 pre3 measurement. Each `SCENARIO` ran in its own process three times with `N=1000`, `WARMUP=200`, and `LATENCY_SAMPLES=200`; the table shows medians and the throughput range across those runs. Values are evidence for this host and workload only, not a general performance guarantee.

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

The Rust path had higher Ruby allocation counts for the small, nested, and array scenarios; this benchmark does not establish a native-allocation total. It measures validation calls after plan construction, so it does not isolate plan-deserialization changes. Peak RSS is process high-water memory, not per-call memory. Reproduce an individual row with, for example:

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
