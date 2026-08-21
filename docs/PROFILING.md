# Profiling

These scripts profile representative validation workloads locally. They are
diagnostic tools, not performance benchmarks or compatibility evidence.

## Prerequisites

Build the native extension once before profiling Ruby code:

```bash
bundle exec rake compile
```

Ruby profiling installs the `stackprof` gem if it is unavailable. Rust
profiling installs `cargo-flamegraph` if it is unavailable. On Linux,
`cargo-flamegraph` requires `perf` permission to record CPU events. If the
preflight reports a restrictive `kernel.perf_event_paranoid` value, ask an
administrator to grant `CAP_PERFMON` or temporarily run:

```bash
sudo sysctl -w kernel.perf_event_paranoid=0
```

The Rust profile runs the `full_schema` Criterion benchmark and can take
several minutes.

## Ruby CPU flamegraph

```bash
script/profile-ruby
```

The script writes a StackProf dump, a text report, and an interactive HTML
flamegraph to `tmp/`. Set `PROFILE_ITERATIONS` to change the default 100,000
validations, or `PROFILE_OUTPUT_DIR` to write elsewhere:

```bash
PROFILE_ITERATIONS=250000 PROFILE_OUTPUT_DIR=tmp/profile-ruby script/profile-ruby
```

Open `tmp/flamegraph.html` in a browser. Wider frames represent more sampled
CPU time; a frame high in the stack is called by the frames beneath it. Search
for application or extension methods before acting on a hot frame, and compare
profiles collected with the same workload and environment.

## Rust CPU flamegraph

```bash
script/profile-rust
```

The generated `ext/dry_validation_rust/flamegraph.svg` is self-contained and
can be opened in a browser. The width of each frame shows sampled CPU time;
the vertical stack shows callers below and callees above. Focus on repeatable,
wide frames in the benchmarked native path, rather than inferring whole-project
performance from a single profile.
