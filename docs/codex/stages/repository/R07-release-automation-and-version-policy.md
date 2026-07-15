# Codex stage R07: release automation and version policy

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `chore/release-automation`  
**Dependencies:** R3–R6

## Version stages

Recommended:

```text
0.1.0-alpha.1
0.1.0-alpha.2
0.1.0-beta.1
0.1.0-rc.1
0.1.0
```

The repository currently uses `0.1.0.pre1`. Choose one prerelease convention and use it consistently in Ruby and Cargo metadata.

## Version synchronization

Create one source of truth or a verification task ensuring:

- Ruby gem version;
- Cargo package version;
- changelog release heading;
- tag

agree.

## Release workflow

Trigger only from a protected tag or manual workflow with environment approval.

Flow:

```text
verify tag/version
run complete CI
run compatibility suite
build source gem
build native gems
clean-install every artifact
generate checksums
create draft GitHub release
publish through trusted publishing after approval
verify RubyGems installation
finalize GitHub release
```

## Trusted Publishing

Use RubyGems trusted publishing/OIDC. Avoid storing a long-lived API key.

Use GitHub environments:

```text
rubygems
```

with manual approval for production release.

## Release notes

Include:

- status level;
- supported Ruby/platform matrix;
- compatibility changes;
- breaking changes;
- fixes;
- performance changes with links to evidence;
- known limitations;
- installation notes;
- checksums/artifact list.

## Failure policy

If some platform build fails:

- do not silently publish a partial release advertised as fully supported;
- either fix/re-run or explicitly remove that platform from the release matrix before publishing.

## Acceptance criteria

- Dry run can build all artifacts without publishing.
- Publishing requires explicit maintainer approval.
- No static RubyGems secret is required.
- Version mismatch fails before artifact publication.
- Post-publish smoke installation verifies RubyGems contents.
- Release can be reproduced from the tag.

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
