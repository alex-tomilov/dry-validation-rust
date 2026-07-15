# Codex stage R00: define product identity and scope

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `docs/product-scope`  
**Dependencies:** None

## Product statement

Recommended wording:

> `dry-validation-rust` is a performance-oriented hybrid Ruby/Rust validation engine with familiar dry-validation-style contract syntax and a precisely documented compatible subset. Rust handles the immutable declarative schema execution path; Ruby preserves dynamic rules and Ruby-specific semantics.

Avoid:

- “drop-in replacement” before proven;
- “fully compatible” without a matrix;
- “Rust rewrite of dry-validation” when arbitrary Ruby rules remain Ruby;
- absolute performance claims.

## Define three surfaces

1. **Native/safe API**
   ```ruby
   Dry::Validation::Rust::Contract
   ```
   This is the primary supported API.

2. **Migration-compatible subset**
   Familiar syntax and behavior backed by differential tests.

3. **Exact compatibility shim**
   Owns upstream-like require paths/constants. Keep experimental and opt-in.

Consider eventually moving exact mode into a second gem:

```text
dry-validation-rust
dry-validation-rust-compat
```

Do not split immediately unless maintenance evidence supports it, but document this as a product architecture decision.

## Versioned compatibility target

Replace “current upstream main” with pinned releases.

Create:

```text
docs/SUPPORT_MATRIX.md
```

Include:

| Gem line | Ruby | Rust MSRV | Platforms | Upstream reference | Status |
|---|---|---|---|---|---|
| 0.1.x | 3.3–3.5 | 1.85 | source build, tested matrix | pinned 1.x versions | alpha |
| 0.2.x | TBD | TBD | native gems | pinned | beta |

## Acceptance criteria

- README clearly states what the project is and is not.
- Safe mode is shown first.
- Exact mode has a prominent collision warning.
- Every support claim points to a support/compatibility document.
- Upstream reference versions are pinned.

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
