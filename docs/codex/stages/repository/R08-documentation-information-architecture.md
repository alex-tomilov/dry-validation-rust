# Codex stage R08: documentation information architecture

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0/P1  
**Suggested branch:** `docs/information-architecture`

## README

Recommended order:

1. one-paragraph product statement;
2. status badge and maturity warning;
3. safe installation/quick start;
4. what Rust handles;
5. what remains Ruby;
6. supported subset summary;
7. exact mode warning;
8. performance caveat;
9. support matrix;
10. links to detailed docs;
11. contributing/security/license.

Keep exhaustive matrices out of the README.

## Documentation set

```text
docs/
  ARCHITECTURE.md
  COMPATIBILITY.md
  FEASIBILITY.md
  VERIFICATION.md
  SUPPORT_MATRIX.md
  MIGRATION.md
  PERFORMANCE.md
  NATIVE_GEMS.md
  TROUBLESHOOTING.md
  RELEASE_POLICY.md
  DEPRECATION_POLICY.md
  ROADMAP.md
```

## Migration guide

Show:

- upstream contract;
- safe parallel Rust contract;
- fixture comparison;
- unsupported feature detection;
- rollback to upstream;
- exact mode only after validation;
- production rollout strategy using shadow validation.

### Shadow validation recommendation

A mature migration path can call both engines on sampled, non-sensitive payloads in separate controlled paths and compare canonical results. Address:

- overhead;
- logging/privacy;
- sampling;
- mismatch storage;
- no user-visible behavior change until confidence is established.

## Performance guide

Include methodology, environment, raw data links, negative results, and the GVL caveat.

## Troubleshooting

Cover:

- Rust/toolchain errors;
- libclang/bindgen;
- Ruby headers;
- native gem versus source build;
- exact-mode collision;
- loading wrong extension;
- unsupported Ruby/platform;
- capturing a minimal reproduction.

## Acceptance criteria

- A new user reaches a working safe-mode example quickly.
- Every limitation has a single canonical documentation location.
- Migration has a rollback path.
- Build failures have actionable troubleshooting instructions.
- Performance claims are reproducible.

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
