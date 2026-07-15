# Codex stage R03: repository metadata and gemspec cleanup

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `chore/project-metadata`

## GitHub repository metadata

Set manually:

- description;
- website/documentation URL when available;
- topics such as:
  - `ruby`;
  - `rust`;
  - `validation`;
  - `native-extension`;
  - `dry-validation`;
  - `magnus`;
  - `rb-sys`.

## Gemspec

Update:

```ruby
spec.description
spec.homepage
spec.metadata["source_code_uri"]
spec.metadata["changelog_uri"]
spec.metadata["documentation_uri"]
spec.metadata["bug_tracker_uri"]
spec.metadata["funding_uri"] # only if real
```

Remove “private experimental gem.”

Review packaged files. The runtime source gem may not need all benchmarks/examples/docs. Use a tracked-file strategy or explicit manifest rather than an overly broad glob when practical.

Keep:

```ruby
spec.metadata["rubygems_mfa_required"] = "true"
```

Add license files and required notices explicitly.

## Package audit

Add a task:

```bash
bundle exec rake package:audit
```

It should:

- build the gem;
- list contents;
- reject secrets and build artifacts;
- verify required files;
- verify native source files are included;
- install into a temporary gem home;
- require the safe entrypoint;
- execute a contract.

## Acceptance criteria

- RubyGems metadata points to valid project resources.
- The built gem contains exactly the intended files.
- No local artifacts, benchmark results, editor files, or credentials are packaged.
- Clean install smoke test passes.

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
