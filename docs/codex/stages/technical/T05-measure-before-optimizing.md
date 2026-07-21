# Codex stage T05: measure before optimizing

**Priority:** P2  
**Dependencies:** `T03`, `T04`

## Assignment

Create reproducible multi-scenario performance evidence, then implement only one
optimization supported by profiling and before/after measurements.

## Work

- Measure valid/invalid flat, nested, array, coercion, predicate, rule, and result
  access scenarios with warmup, distributions, allocations/RSS, and environment.
- Compare against pinned upstream in isolated processes where semantics match.
- Profile candidate work such as path allocation, rule metadata, result/message
  caching, or native fast paths before editing.
- Keep raw local results out of version control unless they are intentional,
  stable release evidence.

## Files

Benchmark harness/methodology plus the single measured implementation area and
its semantic regression tests.

## Scope control

No per-PR benchmark gate on shared runners, CI self-commits, guessed 15% failure
threshold, or benchmark claim from one machine. Use the benchmark-regression
skill for noisy or mixed results.

## Acceptance criteria

- The benchmark corpus verifies semantic equivalence before timing.
- Before/after commands, environment, raw summaries, and negative scenarios are
  reproducible.
- No supported scenario regresses materially without an explicit decision.
- The optimization remains behavior-preserving under full verification.
