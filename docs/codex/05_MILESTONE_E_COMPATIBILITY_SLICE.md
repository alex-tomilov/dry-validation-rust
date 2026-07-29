# Milestone E — Compatibility Slice

Status: ⚪ Not started.
Last updated: 2026-07-29.

## Goal

Define and implement a named compatibility slice with explicit
supported/unsupported lists.

## Tasks

### E-1: Select the Slice

Based on Milestone D benchmark results, select the features that provide
the most value. Prioritize by migration impact.

Candidate features (prioritized):

| Priority | Feature                                  | Rationale                   |
| -------- | ---------------------------------------- | --------------------------- |
| 1        | `Schema.Params` / `Schema.JSON` coercion | Most common migration path  |
| 2        | Nested hash/array validation             | Core use case               |
| 3        | Predicates with arguments                | Required for real contracts |
| 4        | Schema composition (`schema` macro)      | Common in large codebases   |
| 5        | Custom error messages                    | Expected by users           |
| 6        | `rule` blocks with dependencies          | Common pattern              |
| 7        | `each` macro for arrays                  | Frequent in API validation  |
| 8        | `maybe` macro                            | Common for optional fields  |

### E-2: Document the Slice

- Update `COMPATIBILITY.md` with the final supported/unsupported matrix.
- Every "✅ supported" row must have differential fixture coverage.
- Every "❌ unsupported" row must document the error raised.

### E-3: Implement Gaps

- Implement any features in the slice that are not yet complete.
- Add differential fixtures for each.

### E-4: Migration Guide

- Write `docs/MIGRATION.md` explaining how to switch from upstream
  `dry-validation` to this gem for the supported slice.
- Include code examples for each supported feature.
- Document known behavioral differences.

## Acceptance Criteria

- [ ] `COMPATIBILITY.md` has a final, reviewed supported/unsupported matrix.
- [ ] Every supported feature has differential fixture coverage.
- [ ] Every unsupported feature raises a clear error.
- [ ] `docs/MIGRATION.md` exists with code examples.
- [ ] `script/verify` passes.

## Dependencies

- Requires Milestone D (complete). Recommended prerequisite: performance
  impact should be measurable before adding features.
- Blocks Milestone F.
