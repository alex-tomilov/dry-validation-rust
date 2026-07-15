# Codex stage R11: adoption, examples, and supportability

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P2  
**Dependencies:** alpha release

## Example applications

Create small examples:

```text
examples/basic_contract.rb
examples/nested_contract.rb
examples/migration_comparison.rb
examples/rails_service_object.rb
examples/benchmark_custom_contract.rb
```

A minimal Rails example may live in a separate repository later to avoid bloating the gem.

## Production-readiness checklist for adopters

Document:

- pin prerelease version;
- begin in safe side-by-side mode;
- run saved production-shaped fixtures;
- compare canonical output/errors;
- sample shadow traffic where appropriate;
- monitor exceptions and mismatch rates;
- define rollback;
- do not use exact mode until collision risks are understood.

## Support policy

State:

- prereleases may break;
- supported Ruby/platform combinations;
- how long old minor lines receive fixes;
- whether security fixes are backported;
- no guarantee for undocumented internals.

## Acceptance criteria

- Users can evaluate the gem without replacing upstream.
- Examples cover the primary supported API.
- Support expectations are realistic for one maintainer.
- Rollback and mismatch reporting are documented.

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
