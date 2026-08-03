# Milestone B — Common Schema Subset

Status: ✅ Complete (2026-07-29).
Completed via PRs #49–#56 (nine slices) and PRs #65–#71 (Rust hardening).

## Slice-by-Slice Delivery

| Slice | Description                                              | PR  | Status |
| ----- | -------------------------------------------------------- | --- | ------ |
| B-1   | Required/optional keys, key presence, unknown-key policy | #49 | ✅     |
| B-2   | Value types and nil policy                               | #50 | ✅     |
| B-3   | Nested hashes and arrays                                 | #51 | ✅     |
| B-4   | Predicates with arguments                                | #52 | ✅     |
| B-5   | Params/JSON coercion                                     | #53 | ✅     |
| B-6   | Schema composition                                       | #54 | ✅     |
| B-7   | Error messages                                           | #55 | ✅     |
| B-8   | Result API                                               | #56 | ✅     |
| B-9   | Unsupported constructs                                   | #56 | ✅     |

## Rust Hardening

| Task                                                                                   | PR  | Status |
| -------------------------------------------------------------------------------------- | --- | ------ |
| Split `lib.rs` into 6 modules (plan, engine, coercion, predicates, error, ruby_bridge) | #65 | ✅     |
| Typed `PredicateArg` enum replacing raw `serde_json::Value`                            | #66 | ✅     |
| Recursion depth guard (default 128, configurable)                                      | #67 | ✅     |
| 28 Rust unit tests (plan, coercion, predicates, messages)                              | #68 | ✅     |
| 64-input malformed-input resilience corpus                                             | #69 | ✅     |
| `cargo test` wired into CI                                                             | #70 | ✅     |
| `cargo clippy -- -D warnings` wired into CI                                            | #71 | ✅     |

## Acceptance Criteria Verification

| Criterion                                                     | Status  |
| ------------------------------------------------------------- | ------- |
| All nine slices have differential fixture coverage            | ✅ PASS |
| Rust engine handles malformed input without crashing          | ✅ PASS |
| `cargo test` passes in CI                                     | ✅ PASS |
| `cargo clippy` passes with `-D warnings`                      | ✅ PASS |
| Recursion depth guard prevents stack overflow on nested input | ✅ PASS |
| Unsupported constructs raise `UnsupportedFeatureError`        | ✅ PASS |

## Original Scope (Preserved for Reference)

Goal: implement and verify the common schema subset against upstream.

### Slices

1. Required/optional keys, key presence, unknown-key policy.
2. Value types and nil policy.
3. Nested hashes and arrays.
4. Predicates with arguments.
5. Params/JSON coercion.
6. Schema composition.
7. Error messages.
8. Result API.
9. Unsupported constructs.

### Acceptance Criteria

- Each slice has differential fixture coverage.
- Rust engine handles malformed input without crashing.
- `cargo test` and `cargo clippy` pass in CI.
