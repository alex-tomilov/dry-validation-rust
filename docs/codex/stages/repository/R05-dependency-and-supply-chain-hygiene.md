# Codex stage R05: dependency and supply-chain hygiene

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0/P1  
**Suggested branch:** `chore/dependency-security`

## Dependabot

Configure:

```text
.github/dependabot.yml
```

Ecosystems:

- Bundler;
- Cargo;
- GitHub Actions.

Group low-risk development updates where useful. Keep native bridge dependency updates isolated because Magnus/rb-sys changes deserve careful review.

## Audits

Suggested tools:

- `bundler-audit`;
- `cargo audit`;
- `cargo deny` for advisories/licenses/sources where policy is defined.

Do not fail on every unmaintained warning without a triage policy. Document exceptions with expiry dates.

## Lockfiles

- Keep `Gemfile.lock` for development reproducibility.
- Keep native `Cargo.lock` because the Rust crate is an application-like embedded extension and reproducible builds matter.
- Update through reviewed PRs.
- Print dependency versions in verification artifacts.

## Artifact provenance

Later release workflow should:

- use trusted publishing;
- produce checksums;
- retain workflow logs;
- avoid long-lived RubyGems tokens;
- sign tags if the maintainer has a stable signing workflow;
- consider attestations after the core release process works.

## Acceptance criteria

- Automated update PRs are enabled.
- Audits run in CI with documented exception policy.
- No publish credential is available to pull-request jobs.
- Lockfile updates are reviewed and tested.

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
