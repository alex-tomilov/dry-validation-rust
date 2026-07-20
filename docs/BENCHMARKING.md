# Reproducible benchmarking

The benchmark tooling provides two deliberately different paths:

- `script/benchmark-smoke` preserves the original single-schema throughput and
  allocation sanity check used by the Docker `benchmark` command.
- `script/benchmark-suite` produces isolated, multi-workload comparative
  evidence with raw results, environment metadata, RSS, and derived summaries.

Neither path is a production-performance guarantee. The workloads are
synthetic, the current engine operates on Ruby objects under the GVL, and
results apply only to the recorded commit, versions, platform, and hardware.

## Workloads and distributions

The suite covers:

1. `shallow`: a two-field Params schema that exposes fixed native-boundary
   overhead;
2. `nested`: string-key input, coercions, nested data, structural and Ruby
   predicates, and a Ruby contract rule;
3. `array_of_hashes`: a bounded 24-item collection with repeated traversal,
   coercion, and predicates.

Each workload runs valid, invalid, and alternating mixed inputs. Before timing,
each worker records normalized output, error paths, and expected validity. The
controller refuses to summarize Rust and upstream results when their outcome
checksum or processed/success/failure counts differ.

## Quick mode

Quick mode runs one short sample per engine, workload, and distribution. It is
appropriate for CI, local smoke checks, and video demonstrations, but its output
is explicitly marked non-authoritative:

```bash
script/benchmark-suite --mode quick --output tmp/benchmark-quick
```

Use `--engine`, `--workload`, or `--distribution` to narrow a diagnostic run.
The legacy smoke entry points remain available:

```bash
script/benchmark-smoke
bin/dvr benchmark --engine compare --iterations 1000 --warmup 100
```

## Full evidence mode

Full mode defaults to five independent runs, 1,000 warmup calls, and 10,000
measured calls for every engine/workload/distribution combination:

```bash
script/benchmark-suite \
  --mode full \
  --output benchmark/results/build-week-2026 \
  --force
```

Full mode always runs the complete workload, distribution, and two-engine
matrix with at least the default run, iteration, and warmup counts. It refuses
a dirty Git tree unless `--allow-dirty` is explicitly supplied. A
dirty full run is labeled and is not suitable for commit-specific competition
claims. Existing output is never replaced unless `--force` is supplied. The
checked-in [`reproduce.sh`](../benchmark/results/build-week-2026/reproduce.sh)
performs clean-tree and prerequisite checks before replacing the placeholder.

Install the pinned upstream comparison gems separately; they are not runtime
dependencies of `dry-validation-rust`:

```bash
BUNDLE_GEMFILE=benchmark/Gemfile.upstream \
  BUNDLE_IGNORE_CONFIG=1 \
  bundle install
```

The Rust-backed and upstream engines always run in distinct Ruby processes.
This is required because the experimental exact shim and upstream gems own the
same require paths and constants. Upstream is pinned to `dry-validation` 1.11.1
and `dry-schema` 1.16.0.

## Measurements and evidence files

Every worker result records warmup/measured iterations, elapsed seconds,
throughput, allocated Ruby objects, GC count/time, processed and validity
counts, outcome checksum, exit status, and peak RSS. On Linux, the controller
wraps each isolated process with GNU `/usr/bin/time --format %M`; `%M` is the
maximum resident set size in KiB. Full mode fails if that mechanism is absent.
Quick mode records RSS as unavailable on unsupported platforms, and summaries
never compare unavailable RSS with Linux values.

The generated package contains:

```text
environment.json
raw/*.json
summary.json
summary.md
README.md
reproduce.sh
```

`environment.json` records the commit and dirty state, OS/kernel/architecture,
CPU model and count, Ruby/Rust/Cargo and gem versions, mode, configuration, and
a small allowlist of relevant environment variables. It does not capture the
general process environment. Generated files must not contain usernames, home
paths, credentials, or tokens.

`summary.json` derives medians, minima, maxima, and Rust-to-upstream ratios from
all raw samples. `summary.md` presents every workload/distribution comparison;
unfavorable or conflicting scenarios are not filtered out. Any public number
must be traceable to a committed clean full-run package for that exact scenario.

## Interpretation limits

- Schema classes are created before warmup; measurements cover repeated
  contract calls and result construction, not compilation.
- Allocations come from `GC.stat` deltas around the measured loop.
- Peak RSS is process-wide and includes Ruby/native startup and loaded code; it
  is not per-validation memory.
- Engine order alternates between runs, but an idle dedicated host is still
  preferable for full evidence.
- The suite does not establish GVL-free execution, production latency, or
  compatibility beyond the normalized outcomes it checks.
