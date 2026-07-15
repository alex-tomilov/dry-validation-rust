# Codex stage T07: index schema error paths

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `perf/error-path-index`  
**Risk:** Medium  
**Dependencies:** T0, preferably T6

## Problem

Rule dependency checks repeatedly scan all schema messages and compare path prefixes.

## Target

Build a path index once per result.

A simple implementation may store:

```text
exact error paths
all ancestor prefixes of error paths
```

Required queries:

```ruby
error_exactly_at?(path)
error_at_or_below?(path)
error_at_or_above?(path)
dependency_error?(path)
```

## Implementation options

### Option A — sets of arrays

Easiest and likely sufficient:

- `Set` of exact frozen paths;
- `Set` of every ancestor prefix.

### Option B — trie

Consider only after benchmarks show the set approach is insufficient.

## Work steps

1. Add an internal `ErrorPathIndex`.
2. Build it in `SchemaResult`.
3. Replace scans in:
   - `SchemaResult#error?`;
   - `Contract#dependency_error?`;
   - array-rule schema checks where applicable.
4. Ensure base errors and array indices are represented correctly.
5. Normalize paths once before lookup.
6. Benchmark wide invalid schemas and many rules.

## Tests

- exact path;
- ancestor path;
- descendant path;
- sibling path;
- root/base path;
- nested array index;
- `:__index__` schema placeholders versus runtime integer index;
- many errors;
- no errors.

## Acceptance criteria

- Dependency behavior remains identical to differential fixtures.
- Complexity no longer scales as every rule times every schema message.
- Wide invalid-schema benchmark demonstrates a measurable improvement or the change is reverted.
- Added memory remains bounded and documented.

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
