# Changelog

## Unreleased

- Changed the native engine boundary to return a typed `SchemaResult` with
  `#output` and `#errors` accessors.
- Fixed native predicate evaluation to propagate exceptions raised by Ruby
  predicate methods instead of returning validation failures.

## 0.1.0.pre3 — 2026-08-09

- Added `config.validate_keys = true` for `params` and `json` schemas to
  report undeclared keys, including in nested hashes.
- Added supported predicate-composition blocks to schema value declarations.
- Added `:value_coercer` schema processor hooks that run before and after
  native schema evaluation.
- Added direct-field support for custom `dry-types` objects and constructors.
- Added configurable YAML message templates and an optional I18n message
  backend for schema errors.
- Added source-gem package auditing with an isolated installation smoke test.
- Documented the coordinated vulnerability-disclosure process, including a
  90-day post-fix-release embargo and the weekly dependency-audit schedule.

## 0.1.0.pre2 — 2026-08-03

- Added typed native predicate arguments; invalid null and object arguments are
  rejected when compiling a schema plan.
- Added explicit depth limits for native schema plans and nested schema
  traversal.
- Changed `MessageSet#messages` to return a read-only view; use `#add` to add
  messages to a mutable message set.
- Relaxed the native extension's Magnus dependency to compatible `0.8.x`
  patch releases.
- Added coercion boundary and concurrent contract-call coverage.
- Added Rust package-manifest verification to CI.
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
- Added project-management policy, roadmap-to-milestone mapping, issue-quality
  form, canonical labels, work-in-progress limits, and an idempotent GitHub API
  synchronizer with dry-run defaults.
- Replaced the extensive stage catalog with a compact outcome-oriented roadmap
  and aligned project synchronization, issue milestones, and workflow references.
- Removed prose-only documentation/community/project-policy tests and made
  remaining configuration tests protect executable, package, or security
  behavior without freezing exact roadmap counts.

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
