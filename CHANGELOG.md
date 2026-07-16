# Changelog

## Unreleased

- Added product-scope documentation, including the support matrix and pinned
  upstream compatibility references.
- Added canonical verification and benchmark-smoke scripts.
- Added fixture-backed baseline behavior tests and verification documentation.
- Excluded local Cargo target output from source gem file selection.
- Added public RubyGems metadata and a package audit task for source-gem
  contents, artifact rejection, isolated install, and safe-entrypoint smoke
  verification.
- Added GitHub Actions workflows for Ruby/Rust CI, compatibility preflight,
  security audit, package audit, and scheduled fuzz preflight.
- Added Dependabot configuration, dependency audit policy, and dependency
  version capture in canonical verification logs.
- Added contribution, conduct, security, support, and governance policies plus
  structured issue forms and a pull request template.
- Selected `main` as the sole long-lived integration and release branch, with
  documented merge policy, stable required checks, and an owner migration
  checklist for retiring `develop`.
- Added project-management policy, roadmap-to-milestone mapping, issue-quality
  form, canonical labels, work-in-progress limits, and an idempotent GitHub API
  synchronizer with dry-run defaults.

## 0.1.0.pre1 — 2026-07-12

- Added a Magnus/rb-sys native extension with immutable compiled schema plans.
- Added `params`, `json`, and non-coercing `schema` modes.
- Added required, optional, filled, maybe, hash, array, primitive member,
  nested member, coercion, type check, and common predicate support.
- Added ordered Ruby contract rules, multi-key rules, nested paths,
  `rule.each`, key/base failures, context, options, and macros.
- Added result, values, message, message-set, pattern-matching, inheritance,
  external schema reuse, and safe/exact entrypoints.
- Added compatibility, architecture, feasibility, testing, and benchmark
  documentation.

This is an experiment, not a production-compatible release.
