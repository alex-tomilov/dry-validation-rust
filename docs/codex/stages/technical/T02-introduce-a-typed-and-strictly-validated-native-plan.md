# Codex stage T02: introduce a typed and strictly validated native plan

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `fix/strict-native-plan-validation`  
**Risk:** Medium–High  
**Dependencies:** T1

## Problem

Stringly typed field kinds and predicate names make invalid states possible. Unknown native predicates must never silently succeed.

## Target Rust model

Illustrative structure:

```rust
#[derive(Debug, Deserialize)]
struct EnginePlan {
    engine_version: u32,
    mode: SchemaMode,
    fields: Vec<FieldPlan>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SchemaMode {
    Schema,
    Params,
    Json,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum FieldKind {
    Any,
    Nil,
    Bool,
    True,
    False,
    Integer,
    Float,
    Decimal,
    String,
    Symbol,
    Array,
    Hash,
    Date,
    DateTime,
    Time,
}

#[derive(Debug, Deserialize)]
struct FieldPlan {
    name: Option<String>,
    required: bool,
    nullable: bool,
    filled: bool,
    kind: FieldKind,
    member: Option<Box<FieldPlan>>,
    children: Vec<FieldPlan>,
    predicates: Vec<NativePredicate>,
}
```

Predicates should be typed. Either use tagged serde data or custom deserialization:

```rust
enum NativePredicate {
    Gt(ComparableScalar),
    Gteq(ComparableScalar),
    Lt(ComparableScalar),
    Lteq(ComparableScalar),
    MinSize(usize),
    MaxSize(usize),
    Size(usize),
    Odd,
    Even,
}
```

## Structural validation rules

Reject a plan when:

- `engine_version` is unsupported;
- mode is unknown;
- a named schema field has no name;
- an array member has a name where one is forbidden;
- an array has children but no member plan;
- a non-array has a member plan;
- a non-hash field has children;
- duplicate sibling names exist;
- a predicate is invalid for its field kind;
- a size argument is negative or non-integral;
- an odd/even predicate has an argument other than the accepted marker;
- nesting exceeds an intentional safety limit, if a limit is adopted;
- the plan contains unsupported values.

## Ruby-side validation

Validate as early as possible:

- unknown predicate DSL names should fail during schema definition or compilation;
- invalid type/predicate combinations should fail before native execution;
- errors should identify the full schema path.

Example error:

```text
unsupported predicate :odd for field [:profile, :name] of type :string
```

## Error classes

Introduce distinct errors where useful:

```text
PlanSerializationError
PlanVersionError
InvalidPlanError
UnsupportedTypeError
UnsupportedPredicateError
```

Keep the public surface small. Internal Rust errors can map to a smaller documented Ruby hierarchy.

## Tests

### Rust unit tests

- every valid type;
- every valid predicate;
- unknown mode/type/predicate;
- malformed predicate argument;
- invalid structure combinations;
- duplicates;
- wrong engine version;
- deeply nested plan;
- malformed JSON;
- no panic for arbitrary JSON bytes accepted by the parser.

### Ruby integration tests

- unsupported predicate fails at compile time;
- error includes path and predicate;
- invalid schema never creates a partially usable engine;
- public error class and cause are stable;
- engine version mismatch is explicit.

## Acceptance criteria

- No unknown native predicate can evaluate as successful.
- All invalid plan structures fail during engine construction.
- Plan errors include enough context to locate the schema definition.
- Rust deserialization and validation have direct unit coverage.
- No behavior regression for valid baseline schemas.

---

---

## Mandatory execution sequence

1. Inspect relevant code, tests, build files, and documentation.
2. Restate current behavior and the minimal proposed design.
3. Identify assumptions in this prompt that do not match the current repository.
4. Add/update regression and boundary tests.
5. Implement the focused change.
6. Run focused checks.
7. Run canonical full verification.
8. Review the diff for unrelated behavior or compatibility changes.
9. Update documentation/changelog only where justified.
10. Stop without publishing or changing remote repository settings.

## Scope control

- Do not perform adjacent roadmap stages.
- Do not add unrelated DSL features.
- Do not hide an upstream mismatch by weakening canonicalization or tests.
- Do not claim optimization without measurements.
- If the full stage cannot safely fit one PR, provide a PR breakdown and implement the first self-contained part.

## Final response format

Return:

1. **Summary**
2. **Current behavior confirmed**
3. **Files changed**
4. **Implementation details**
5. **Design decisions / rejected alternatives**
6. **Public API and compatibility impact**
7. **Tests and exact commands**
8. **Benchmark evidence**, if applicable
9. **Known limitations / follow-ups**
10. **Risks / rollback**
11. **No-release confirmation**
