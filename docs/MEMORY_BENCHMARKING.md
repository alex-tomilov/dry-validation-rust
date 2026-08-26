# Process-memory benchmarking

`ruby_allocated_objects_per_call` and `MemoryProfiler` describe Ruby-side
allocation activity. They do not describe every byte allocated by the Rust
extension or by the process as a whole.

For process-level memory evidence, use:

```bash
bundle exec rake compile
bundle exec script/benchmark-memory-footprint
```

This is intentionally separate from throughput publication. Throughput wants
both engines to run long enough for stable timing, so the publication runner
uses engine-specific calibrated iteration counts. Memory comparison wants the
same amount of work, so the memory runner calibrates `N` from upstream and then
uses exactly the same `N` and warmup for Rust and upstream.

Defaults are five runs and roughly two seconds of upstream work per scenario.
Useful overrides:

```bash
MEMORY_RUNS=7 MEMORY_TARGET_SECONDS=5 \
  bundle exec script/benchmark-memory-footprint

SCENARIO=wide_nested_object MEMORY_RUNS=7 \
  bundle exec script/benchmark-memory-footprint
```

The lower-level fixed run records snapshots immediately after warmup/GC and
immediately after the timed validation loop. On Linux it records:

- current RSS (`VmRSS`);
- peak RSS (`VmHWM`);
- PSS from `/proc/<pid>/smaps_rollup`;
- USS as private clean + private dirty + private hugetlb resident pages;
- virtual/data/swap values when available;
- before/after deltas and additional peak-RSS growth during the measured loop.

On non-Linux systems the portable fallback records current RSS only. It does
**not** relabel current RSS as peak RSS.

## What these metrics mean

**Peak RSS** is the maximum resident set of the process. It includes resident
Ruby heap pages, native/Rust heap allocations, stacks, and mapped resident
pages. It is the closest simple metric here to "how much physical memory could
this process occupy at once", but shared pages are counted in full.

**PSS** (proportional set size) divides shared resident pages among the processes
sharing them. It is often a better single-process footprint comparison than RSS
when shared libraries differ.

**USS** (unique set size) is private resident memory. It is useful for asking how
much memory would actually be freed if this process disappeared.

None of RSS/PSS/USS means "total bytes ever allocated". A process can allocate
and free gigabytes over time while keeping a small resident footprint. Measuring
cumulative allocation traffic across both Ruby and Rust requires allocator
instrumentation (for example heaptrack or Valgrind Massif on Linux) and should be
a separate profiling experiment because instrumentation materially distorts
runtime performance.

## Why more Ruby objects can still mean less memory

`GC.stat[:total_allocated_objects]` is an object **count**, not a byte count and
not a live-object count. More short-lived small wrapper objects can coexist with
fewer/lower-size live heap pages, less retained state, and a smaller native
working set. Conversely, fewer Ruby objects can be larger or live longer and
cause MRI to grow/retain more heap pages.

Therefore report Ruby allocation count and process footprint independently.
Neither should be used as a proxy for the other. The generated report also shows
resident-memory growth during the measured loop, which is useful when looking for
retention/leak-like behavior that can matter under sustained production load.
