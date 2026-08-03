# Milestone D — Performance Proof

Status: ⚪ Not started.
Last updated: 2026-07-29.

## Goal

Produce honest, reproducible benchmark evidence for the performance claims
made in the README and ARCHITECTURE.md.

## Tasks

### D-1: Define Benchmark Payload Matrix

Create representative payloads:

| Payload               | Description                            |
| --------------------- | -------------------------------------- |
| Small hash            | 5 keys, flat, no coercion              |
| Medium hash           | 20 keys, 2 levels of nesting           |
| Nested hash           | 5 levels deep, mixed types             |
| Large array           | 10,000 elements, each a 5-key hash     |
| Coercion-heavy params | 50 keys, all requiring Params coercion |
| Mixed                 | Combination of above                   |

### D-2: Implement Benchmark Harness

- Use `benchmark/ips` or `benchmark-memory` gems.
- Run each payload through both this gem and upstream `dry-validation`.
- Measure: throughput (ips), allocation count, GC time.
- Run on at least 3 iterations with warmup.
- Record Ruby version, Rust version, OS, CPU, commit SHA.

### D-3: Run and Record

- Run on CI (ubuntu-latest) and locally (developer machine).
- Record results in `docs/BENCHMARKS.md`.
- Include hardware specs, versions, and commit SHA.

### D-4: Analyze

- Identify where the Rust path helps and where it doesn't.
- If the Rust path is slower for small payloads, document why (FFI overhead).
- If the Rust path is faster for large arrays, document the crossover point.

### D-5: Publish

Publication requirements:

- **Negative/neutral results must have equal prominence.** If the Rust path
  is only 1.2× faster on a 5-key hash but 8× faster on a 10,000-element array,
  say exactly that. Do not cherry-pick.
- **`benchmark/README.md`** must explain how to reproduce results locally.
- **README performance wording must match measured scope.** If benchmarks show
  benefit only for large arrays, the README must not say "performance-oriented"
  without qualification.
- **No raw CSV/JSON data dumps committed.** Summarize in tables. Raw data
  can be linked as CI artifacts.

### D-6: Update README and ARCHITECTURE.md

- Replace "performance-oriented" with specific, measured claims.
- Link to `docs/BENCHMARKS.md`.

## Acceptance Criteria

- [ ] `docs/BENCHMARKS.md` exists with results for all 6 payload types.
- [ ] `benchmark/README.md` explains reproduction steps.
- [ ] Results include negative/neutral findings with equal prominence.
- [ ] README and ARCHITECTURE.md updated to match measured evidence.
- [ ] Benchmark harness runs in CI (even if results are not gated).
- [ ] No raw data files committed to the repo.

## Dependencies

- Requires Milestone C (complete).
- Blocks Milestone E.
