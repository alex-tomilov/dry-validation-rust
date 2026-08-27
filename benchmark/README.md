# Schema throughput benchmark

This directory contains the representative validation benchmark matrix used to
compare `dry-validation-rust` with upstream `dry-validation`. Use it to explore
a change locally or to produce machine-readable measurements. For
publication-quality evidence, use `script/benchmark-publication` instead; its
repeated, calibrated protocol is documented in
[`docs/BENCHMARKING.md`](../docs/BENCHMARKING.md).

## Prerequisites

- Ruby 3.3 or a supported project runtime;
- Rust and Cargo, to compile the native extension;
- Bundler and the dependencies from `Gemfile`, including the pinned upstream
  `dry-validation` version.

From a clean checkout, install dependencies and build the extension:

```bash
bundle install
bundle exec rake compile
```

## Run a comparison

`script/benchmark` runs the harness from any current directory. With no
environment variables it compares both engines across the full scenario matrix
and prints a human-readable report:

```bash
bundle exec script/benchmark
```

For a quick reproducibility check that normally completes well within ten
minutes, run one representative scenario with short showcase settings:

```bash
ENGINE=all SCENARIO=small_form N=1000 WARMUP=100 LATENCY_SAMPLES=50 \
  IPS_WARMUP=0.2 IPS_TIME=0.5 MEMORY_PROFILE_N=100 \
  bundle exec script/benchmark
```

Select an engine with `ENGINE=rust`, `ENGINE=upstream`, or `ENGINE=all`
(the default). `SCENARIO` accepts one scenario name, such as `medium_form` or
`array_of_objects`; omit it for the full matrix. Set `VALIDATE_KEYS=true` for
the strict-key variant of a scenario.

## Output formats

`FORMAT=text` is the default. It reports warmed `Benchmark.ips` throughput,
Ruby-side allocation detail from `MemoryProfiler`, and peak process RSS for
each selected scenario. Use it for local inspection, not a public performance
claim from a single run.

`FORMAT=json` emits one stable JSON object. Its top-level fields are
`benchmark`, `environment`, and `results`. `environment` records the Git,
Ruby, platform, toolchain, and selected fixed-run settings. Each result records
the engine and version, scenario, throughput per second, p50/p95/p99 latency
in microseconds, Ruby objects allocated per call, and process-memory metrics.
Set `MEMORY_PROFILE=true` to additionally include `MemoryProfiler` allocation
totals and retained-memory metrics for each selected scenario and engine.
For example:

```bash
FORMAT=json ENGINE=all SCENARIO=small_form \
  N=10000 WARMUP=1000 LATENCY_SAMPLES=500 MEMORY_PROFILE=true MEMORY_PROFILE_N=1000 \
  bundle exec script/benchmark > schema-throughput.json
```

The harness also supports `FORMAT=github-action-benchmark` for the CI dashboard
payload; it is not intended as the general interchange format.

`N`, `WARMUP`, and `LATENCY_SAMPLES` control the fixed measurement loop, its
warmup, and the number of sampled latency calls. `IPS_WARMUP` and `IPS_TIME`
affect only the text showcase. `MEMORY_PROFILE_N` controls the text showcase
and opt-in JSON profiler call count. Keep fixed-run settings the same for both
engines when comparing them.

## Comparing with upstream

Use `ENGINE=all` to run both engines against the same selected scenarios and
settings. The default upstream baseline is `dry-validation 1.11.1`; override
it deliberately with `UPSTREAM_VERSION` only when testing another installed
version:

```bash
ENGINE=all UPSTREAM_VERSION=1.11.1 SCENARIO=nested_object \
  bundle exec script/benchmark
```

Compare runs only on the same machine and power mode, with unrelated heavy
workloads stopped. Throughput, latency, and RSS are host- and workload-specific;
Ruby allocation counts are not total process-memory allocation. For results
intended for the README, release notes, or external publication, use the
calibrated repeated-run workflow in `script/benchmark-publication` rather than
choosing a favorable interactive result.
