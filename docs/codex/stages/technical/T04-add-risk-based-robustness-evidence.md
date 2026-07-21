# Codex stage T04: add risk-based robustness evidence

**Priority:** P0/P1  
**Dependencies:** `T02`; coordinate compatible cases with `T03`

## Assignment

Build confidence around failure-prone behavior using focused properties, fuzzing,
GC/compaction stress, concurrency under the GVL, and package/load boundaries.
Prioritize risk rather than a coverage percentage.

## Work

- Add deterministic boundary/property tests for malformed plans, coercion edges,
  nesting, arrays, Unicode, large integers, and missing fields.
- Add bounded fuzz targets for pure Rust plan parsing/validation first.
- Exercise shared compiled schemas across threads without claiming GVL-free work.
- Test GC lifetime and compaction for any Ruby object retained by native state.
- Use fixed seeds or reportable seeds and strict time bounds.

## Files

Focused Ruby/Rust tests, fuzz targets/corpus policy, and CI only where the tests
are stable and proportionate.

## Scope control

Do not add trivial random loops, empty placeholder tests, arbitrary 80/90%
coverage gates, exclusions to raise coverage, or badges for unhosted data.

## Acceptance criteria

- Tests target named failure modes and reproduce deterministically.
- Fuzz/property failures leave a minimal reusable regression.
- Concurrency and GC tests are stable and bounded.
- Coverage may be reported diagnostically but is not the definition of done.
