# Codex stage T06: build a differential compatibility harness

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0 for claims; P1 for implementation timing  
**Suggested branch:** `test/differential-compatibility`  
**Risk:** Medium  
**Dependencies:** T0; best after T4

## Goal

Execute equivalent contracts and inputs against:

1. pinned upstream `dry-validation`/`dry-schema`;
2. `dry-validation-rust`;

and compare canonicalized results in separate Ruby processes.

## Why separate processes

Exact mode and upstream may own the same require paths and constants. Process isolation also prevents loaded-gem and monkey-patch contamination.

## Proposed layout

```text
compat/
  Gemfile
  contracts/
  fixtures/
  runners/
    rust_runner.rb
    upstream_runner.rb
  canonicalize.rb
  compare.rb
  manifest.yml
test/compatibility_test.rb
```

## Fixture manifest

Each scenario should declare:

```yaml
id: params_integer_valid
contract: contracts/basic_params.rb
input: fixtures/basic_params/valid.json
compare:
  output: exact
  success: exact
  errors:
    paths: exact
    codes: exact
    text: documented
  exception: exact_class
tags:
  - params
  - integer
```

## Canonical result

Use a JSON-safe representation:

```json
{
  "status": "result",
  "success": false,
  "output": {},
  "errors": [
    {
      "path": ["age"],
      "code": "type?",
      "text": "must be an integer",
      "source": "schema",
      "meta": {}
    }
  ],
  "context": {}
}
```

For exceptions:

```json
{
  "status": "exception",
  "class": "ArgumentError",
  "message": "...",
  "phase": "contract_definition|initialization|call"
}
```

## Initial scenario groups

1. Loading and constants.
2. Required/optional keys.
3. Params, JSON, plain schema modes.
4. Primitive coercions.
5. Missing/nil/empty distinctions.
6. Nested hashes.
7. Arrays and arrays of hashes.
8. Native predicates.
9. Ruby predicates.
10. Rules and rule skipping.
11. `rule.each`.
12. Macros.
13. Options/context.
14. Inheritance and imports.
15. Result/message API.
16. Unsupported features.
17. Large integer and edge coercions.
18. Encoding and custom-object behavior.

## Comparison policy

Not every message string must initially be identical. Classify each field:

- exact;
- normalized;
- intentionally different;
- not yet supported.

Every intentionally different case must link to `COMPATIBILITY.md`.

## Acceptance criteria

- The harness can run one scenario, a tag group, or the complete suite.
- Upstream versions are pinned and printed in output.
- A mismatch shows a readable structured diff.
- CI uploads mismatch artifacts.
- Every feature marked supported has at least one positive and one negative differential scenario.
- Compatibility claims in README link to the tested matrix.

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
