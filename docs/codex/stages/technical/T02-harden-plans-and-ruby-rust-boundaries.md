# Codex stage T02: harden plans and Ruby/Rust boundaries

**Priority:** P0  
**Dependencies:** `T01`

## Assignment

Make compiled plans immutable and strictly typed, and make every Ruby/Rust
failure path explicit. Work in regression-sized slices: plan validation,
exception propagation, numeric correctness, or resource bounds.

## Work

- Reject unknown modes, field types, predicates, malformed arguments, excessive
  depth, and excessive plan size before runtime traversal.
- Preserve arbitrary-precision Ruby integer semantics; never route integers
  through `i64` or `f64` merely for convenience.
- Replace panic/default/silent-success paths with typed errors while preserving
  expected validation failures.
- Remove Marshal-based schema copying and prove parent/import/compiled-plan
  mutation isolation.
- Review Ruby object rooting, marking, compaction, and exception lifetimes.

## Files

Native plan/FFI modules, Ruby schema builders, and focused malformed-plan,
mutation, exception, numeric-boundary, and GC tests.

## Scope control

Do not turn missing optional Ruby constants or unexpected Ruby exceptions into
ordinary validation failures. Do not widen the supported DSL.

## Acceptance criteria

- Unsupported states fail loudly before they can silently validate input.
- No Rust panic crosses FFI and no undocumented runtime `unwrap`/`expect` remains.
- Compiled behavior cannot change through later builder or registry mutation.
- Numeric, exception, depth, and malformed-plan boundaries have regressions.
