# Codex stage T06: evaluate batch and streaming APIs

**Priority:** P3  
**Dependencies:** `T05` and a stable normal API

## Assignment

Evaluate, rather than assume, whether a separate Rust-owned batch or streaming
API can provide useful parallelism or bounded memory. Start with ownership,
semantics, and benchmark design; implementation is optional.

## Work

- Define a restricted input/plan/result representation owned by Rust while the
  GVL is released.
- Prove no Ruby API, allocation, callback, exception object, or unrooted Ruby
  object is reachable in the released section.
- Define ordering, error paths, early termination, backpressure, cancellation,
  and partial-summary behavior for streaming.
- Measure copy/serialization overhead, throughput, latency, and peak RSS.

## Files

Feasibility/design evidence, experimental code behind an opt-in API if justified,
semantic comparison tests, and reproducible benchmarks.

## Scope control

The normal engine uses Ruby objects and remains under the GVL. Ruby blocks and
Enumerators require the GVL. Stop without implementation if safety or benefit is
not demonstrated.

## Acceptance criteria

- Ownership and FFI safety are reviewable and tested.
- Ordinary and experimental paths agree on their shared semantic subset.
- Parallelism or memory claims have reproducible evidence.
- The experimental path does not delay or complicate the normal API.
