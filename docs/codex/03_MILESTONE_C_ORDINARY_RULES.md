# Milestone C — Ordinary Rules Subset

Status: 🔵 Active.
Last updated: 2026-07-29.

## Current State

| Area                          | Status         | Evidence                      |
| ----------------------------- | -------------- | ----------------------------- |
| Rule tests                    | ~10 scenarios  | `test/rules_test.rb`          |
| Differential rule cases       | ~15 cases      | `test/fixtures/differential/` |
| Dedicated 50-case rule corpus | ❌ Not started | —                             |
| Dependency/isolation stress   | ❌ Not started | —                             |
| Code-quality tasks C-Q1–C-Q4  | ❌ Pending     | See below                     |

Estimated completion: ~20%.

## Goal

Make ordinary rules (`rule` blocks, `key?`, `value()`, simple dependencies)
behave compatibly for the common schema subset.

## Tasks

### C-1: Build a Dedicated Rule Corpus

Create `test/fixtures/differential/rules/` with at least 50 cases.

Suggested distribution:

| Category                                    | Minimum Cases |
| ------------------------------------------- | ------------- |
| Single-key rules (`rule(:name)`)            | 10            |
| Multi-key rules (`rule(:a, :b)`)            | 8             |
| Nested-path rules (`rule(:address, :city)`) | 8             |
| `key?` / `value()` guards                   | 6             |
| Cross-key dependencies                      | 6             |
| Rules on arrays (`rule(:items)`)            | 6             |
| Rules with coercion interaction             | 6             |

Each case must run in an isolated subprocess against both this gem and
pinned upstream, comparing output values and error messages.

### C-2: Rule Dependency and Isolation Stress

- Test that rules execute in definition order.
- Test that a failing rule does not prevent subsequent rules from running.
- Test that rules on missing keys behave identically to upstream.
- Test that rules on coerced values see the coerced value, not the raw input.

### C-3: Wire Rule Corpus into CI

- Add rule fixtures to `compatibility.yml` workflow.
- Ensure the rule corpus runs on every PR.

### C-Q1: Unify Predicate Evaluation

**Problem:** Predicate evaluation logic exists in three places:

1. Rust (`predicates.rs`) — native predicates.
2. `Schema#predicate_valid?` (`schema.rb`) — Ruby-owned predicates.
3. `Evaluator#execute_predicate_macro` (`evaluator.rb`) — duplicated predicate
   logic for rule macros.

**Task:** Extract a single `RubyPredicates.evaluate(name, value, argument)`
method. Both `Schema` and `Evaluator` call it. The Rust side handles the native
set; Ruby handles the rest through one canonical entry point.

**Acceptance:** No predicate logic duplicated across files. All existing tests
pass. New unit tests for `RubyPredicates` cover boundary cases.

### C-Q2: Unify `Undefined` Sentinels

**Problem:** `Path::Undefined` and `Contract::Undefined` are two separate
`frozen Object.new` sentinels. Identity checks (`equal?`) fail across them.

**Task:** Define one `Dry::Validation::Rust::Undefined` and alias it in both
`Path` and `Contract`.

**Acceptance:** Single sentinel object. All existing tests pass.

### C-Q3: Fix `MessageSet#freeze`

**Problem:** `MessageSet#freeze` calls `to_h.freeze` but discards the result.
The frozen hash is immediately garbage-collected.

**Task:** Either cache the frozen hash in an ivar, or remove the no-op line.
Add a comment explaining the design intent.

**Acceptance:** `MessageSet#freeze` either caches or does not allocate.
Test that `message_set.freeze.to_h.frozen?` is true.

### C-Q4: Split `schema.rb`

**Problem:** `schema.rb` is 480 lines containing 5 classes: `SchemaResult`,
`Schema`, `Schema::FieldDefinition`, `Schema::DSL`, `Schema::FieldBuilder`.

**Task:** Split into:

    lib/dry/validation/rust/
    ├── schema.rb               # Schema class only
    ├── schema/
    │   ├── dsl.rb              # DSL + FieldBuilder
    │   ├── field_definition.rb # FieldDefinition + Predicate struct
    │   └── result.rb           # SchemaResult (or merge into result.rb)

**Acceptance:** All existing tests pass. No file exceeds 200 lines.
`require` graph is acyclic.

## Acceptance Criteria

- [ ] 50+ rule fixture cases pass differentially against upstream.
- [ ] Rule dependency and isolation stress tests pass.
- [ ] Rule corpus runs in CI on every PR.
- [ ] C-Q1: Predicate evaluation unified (no duplication).
- [ ] C-Q2: Single `Undefined` sentinel.
- [ ] C-Q3: `MessageSet#freeze` fixed.
- [ ] C-Q4: `schema.rb` split into ≤4 files, each ≤200 lines.
- [ ] `script/verify` passes.

## Dependencies

- Requires Milestone B (complete).
- Blocks Milestone D.
