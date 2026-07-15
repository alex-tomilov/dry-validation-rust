# Codex stage T01: separate mutable DSL builders from immutable compiled plans

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `fix/immutable-schema-plan`  
**Risk:** Medium  
**Dependencies:** T0

## Problem

The current Ruby `FieldDefinition` is mutable and is exposed through `Schema#fields`. The top-level fields array is frozen, but individual definitions, predicates, children, and members can still be changed after the Rust engine has been compiled.

This can make:

- Ruby metadata;
- Ruby-owned predicate execution;
- `key_paths`;
- inspection;
- the compiled native plan

disagree with one another.

`Marshal` is currently used to copy imported fields, which is opaque and will fail if future definitions contain non-marshallable objects.

## Target design

Use two layers:

```text
Schema::DSL / FieldBuilder
    mutable, temporary, never exposed after compile

CompiledSchemaPlan / FieldPlan / PredicatePlan
    deeply immutable, validated, exposed read-only
```

Suggested Ruby value objects:

```ruby
PredicatePlan = Data.define(:name, :argument)

FieldPlan = Data.define(
  :name,
  :required,
  :nullable,
  :filled,
  :type,
  :member,
  :children,
  :predicates
)
```

`Data` is available on the currently required Ruby line. An immutable custom class is also acceptable if it provides clearer validation.

## Implementation steps

1. Rename the mutable object to communicate its role:
   - `FieldDefinition` → `MutableFieldDefinition`, `FieldBuilderState`, or similar.
2. Add a compiler that recursively converts builder state into `FieldPlan`.
3. Freeze/copy collections recursively:
   - `children`;
   - `predicates`;
   - array/hash predicate arguments where copying is safe;
   - path arrays.
4. Decide how external Ruby objects in predicate arguments are handled:
   - immutable known scalars may be reused;
   - mutable containers should be copied and frozen;
   - arbitrary objects should either be accepted as identity-preserved Ruby-owned values or rejected explicitly.
5. Replace `Marshal.load(Marshal.dump(field))` with explicit plan cloning/import.
6. Compile native JSON from the immutable plan only.
7. Precompute and freeze:
   - native plan payload;
   - `key_paths`;
   - Ruby predicate traversal data;
   - required runtime-class flags if introduced later.
8. Do not expose mutable builder state from `Schema`.
9. Decide whether `Schema#fields` is public:
   - if retained, return immutable `FieldPlan` objects;
   - otherwise introduce a narrower introspection API and deprecate raw exposure.
10. Add a plan invariant checker in Ruby before calling Rust.

## Regression tests

Add tests that attempt to mutate:

```ruby
schema.fields
schema.fields.first
schema.fields.first.children
schema.fields.first.predicates
schema.fields.first.predicates.first.argument
schema.key_paths
```

Expected outcomes:

- mutation raises `FrozenError`, or
- the exposed value is a defensive copy whose mutation cannot affect validation.

Add a behavioral test:

1. Compile a schema expecting integer.
2. Attempt every available mutation path to string.
3. Validate `"12"`.
4. Assert metadata and native behavior remain consistent.

Add import tests:

- importing a schema does not share mutable nested containers;
- compiling a child contract cannot alter the parent;
- imported regex/container predicate arguments retain intended semantics.

## Acceptance criteria

- No supported public operation can change compiled schema semantics.
- `Schema#fields`, if present, is deeply immutable.
- No `Marshal` copying remains in schema import.
- Parent, child, and imported schemas do not share mutable compilation state.
- Baseline behavior remains unchanged.
- Documentation states that compiled schemas are immutable and thread-safe for concurrent calls.

## Rollback strategy

Keep the old builder classes temporarily behind internal names until all DSL tests pass. Do not retain two public plan representations.

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
