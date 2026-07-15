# Codex stage R06: native binary gem strategy

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1, essential for broad adoption  
**Suggested branch:** `chore/native-gem-packaging`  
**Dependencies:** R4, technical correctness foundation

## Goal

Users on supported platforms should be able to install without Rust, Cargo, Ruby headers, libclang, or a C toolchain.

## Candidate platforms

Start small and expand only with passing clean-install tests:

```text
x86_64-linux
aarch64-linux
arm64-darwin
x86_64-darwin
x64-mingw-ucrt
```

Decide whether Linux gems target glibc only or also musl.

## Tooling

Evaluate the current `rb-sys`/`rake-compiler` ecosystem for native gem builds. Use maintained official patterns rather than inventing custom cross-compilation.

## Release artifact tests

For every platform artifact:

1. build;
2. inspect gem contents and platform metadata;
3. install in a clean container/VM without Rust;
4. require `dry/validation/rust`;
5. run representative contracts;
6. print loaded extension path;
7. verify architecture;
8. run at least a smoke subset of tests;
9. retain checksums.

## Source fallback

Continue publishing a generic source gem unless there is a strong reason not to.

Document:

- native gem selection;
- source-build fallback;
- troubleshooting;
- supported Ruby ABI strategy;
- whether stable API mode avoids per-Ruby-version native binaries;
- platform limitations.

## Acceptance criteria

- Every advertised platform has automated build and clean-install verification.
- Native gems do not require Rust at install time.
- Source fallback remains functional.
- Unsupported platforms fail with actionable build documentation.
- No platform is listed as supported based only on successful compilation.

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
