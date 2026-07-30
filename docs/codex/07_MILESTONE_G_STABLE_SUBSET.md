# Milestone G — Stable Subset

Status: ⚪ Not started.
Last updated: 2026-07-29.

## Goal

Prepare a public release candidate with docs, examples, and support policy.

## Tasks

### G-1: Documentation Review

- Review all documentation for accuracy against the final feature set.
- Remove or update any claims not backed by evidence.
- Ensure README, ARCHITECTURE.md, COMPATIBILITY.md, and MIGRATION.md are
  consistent.

### G-2: Example Suite

- Create `examples/` with runnable examples for each supported feature.
- Each example must be tested in CI.
- Include a "quick start" example that works in under 10 lines.

### G-3: Support Policy

- Define supported Ruby versions, Rust versions, and platforms.
- Document in `SUPPORT.md`.
- Define the deprecation policy for future releases.

### G-4: Security Review

- Run `cargo audit` and `bundle audit` clean.
- Review FFI boundary for memory safety.
- Ensure no `unsafe` blocks without justification comments.
- Review recursion depth guard and input size limits.

### G-5: Release Candidate

- Tag `v0.1.0-rc1`.
- Publish pre-release gem.
- Announce in relevant communities (Ruby Weekly, dry-rb Discourse).

### G-6: Post-Release Monitoring

- Monitor GitHub issues for the first 30 days.
- Track installation counts on RubyGems.
- Collect feedback on the compatibility slice.

### G-7: Community and Naming Review

Before publication:

- **Naming/affiliation discussion with dry-rb / Hanakai maintainers.**
  The name `dry-validation-rust` implies affiliation. Get explicit blessing
  or adjust the name (e.g., `dry-validation-native`, `turbo-validation`).
  Open a discussion on the dry-rb / hanami GitHub org or Discourse. Frame it
  as "here's a feasibility study, I'd love feedback on the approach."

- **"Why should I use this?" README section.** Add honest positioning:

  > **When to consider this gem:**
  >
  > - You validate large arrays of nested hashes (e.g., bulk API imports)
  >   and the schema path is a measurable bottleneck.
  > - You want to keep your existing `dry-validation` contract syntax while
  >   moving the hot path to native code.
  > - You are willing to run a pre-release gem and report issues.
  >
  > **When to stay on upstream:**
  >
  > - You need i18n messages, hints, monads, or the full predicate library.
  > - You need production support and semantic versioning guarantees.

- **Governance right-sizing.** For a single-maintainer prototype, collapse
  process docs (AGENTS.md, docs/codex/, docs/decisions/, docs/tasks/,
  GOVERNANCE.md, PROJECT_MANAGEMENT.md) into a single `docs/PROCESS.md`
  or remove them until the project has multiple contributors. Keep
  CONTRIBUTING.md, SECURITY.md, CHANGELOG.md, and ARCHITECTURE.md.

## Go/No-Go Questions

1. Does `script/verify` pass on all supported platforms?
2. Are all benchmark claims backed by published results?
3. Is the compatibility matrix accurate and complete?
4. Are all unsupported features documented with clear errors?
5. Is the migration guide tested by at least one external user?
6. Are precompiled gems available for the primary platforms?
7. Is the security review complete?
8. Is the support policy documented?
9. Is the changelog up to date?
10. Is the release process documented?
11. Is the naming/affiliation question resolved with dry-rb maintainers?
12. Does the README honestly position the gem's strengths and limitations?

## Acceptance Criteria

- [ ] All documentation reviewed and accurate.
- [ ] Example suite exists and is tested in CI.
- [ ] Support policy documented.
- [ ] Security review complete (cargo audit, bundle audit, FFI review).
- [ ] Release candidate tagged and published.
- [ ] Naming/affiliation resolved with dry-rb / Hanakai community.
- [ ] README includes honest positioning section.
- [ ] Governance documentation right-sized for project scale.
- [ ] All 12 go/no-go questions answered "yes".

## Dependencies

- Requires Milestone F (complete).
- Final milestone.
