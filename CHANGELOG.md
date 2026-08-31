# Changelog

## Unreleased

- Made the documented compatibility matrix YAML-backed and checked for sync in CI.
- Added hosted Rust API reference documentation to the GitHub Pages site.
- Added a getting-started guide for installation, first contracts, macros,
  web integration, and native-build troubleshooting.
- Added an mdBook documentation site with sidebar navigation, native search,
  and GitHub Pages deployment from `main`.
- Added a searchable YARD Ruby API reference to the GitHub Pages site.
- Added opt-in MemoryProfiler allocation and retained-memory totals to the
  schema-throughput JSON benchmark matrix for both engines.
- Added a documented `script/benchmark` entrypoint for reproducible local
  schema-throughput comparisons and JSON measurements.
- Improved unsupported schema DSL errors with migration guidance for boolean
  predicate composition, UUID predicates, and filtering.
- Added a five-minute pinned-upstream differential fuzz CI job covering 1,000
  generated schema/input pairs per run.
- Added a blocking pull-request CI job for the pinned upstream differential
  compatibility suite, with uploaded test logs.
- Made publication benchmark duration and live progress visible, so long
  full-matrix runs can be distinguished from stalled executions.
- Added a repeatable publication benchmark runner with calibrated measurements,
  checkpoints, environment metadata, and documented evidence guidance.
- Added CI checks for Markdown style violations and broken documentation links.
- Added local Ruby and Rust CPU-flamegraph scripts for diagnosing validation
  hot paths.
- Added a schema-throughput pull-request regression gate with a 5% p95-latency
  threshold and a GitHub Pages benchmark dashboard refreshed from trusted runs.
- Added Ruby line-coverage reporting and a Codecov quality gate to CI.
- Added native Rust line-coverage reporting and a Codecov quality gate to CI.
- Added beta Rust CI coverage and a weekly nightly Miri check for the native extension.
- Added an allowed-to-fail Windows CI job that compiles the native extension
  and runs the Ruby test suite with RubyInstaller's UCRT toolchain.
- Fixed deeply nested Ruby type processing to avoid exhausting Windows' Ruby
  VM stack during validation.
- Added Gitleaks secret scanning to the Security workflow for pull requests,
  protected-branch pushes, scheduled runs, and manual runs.
- Added local release automation for version and Cargo-lockfile updates, dated
  changelog sections, and release tags, plus pull-request changelog enforcement.
- Added representative throughput, allocation, and native Criterion benchmark
  coverage with regression gates where main-branch baselines are available.
- Improved source and native-gem build reliability across supported targets,
  including MinGW source builds and cross-compilation packaging.
- Added release-publishing preflight, signed native-gem artifacts, and trusted
  RubyGems publishing support.

## 0.1.0.pre5 — 2026-08-18

- Added pluggable schema message backends through custom `MessageBackend`
  subclasses.
- Changed the native engine boundary to return a typed `SchemaResult` with
  `#output` and `#errors` accessors.
- Fixed native predicate evaluation to propagate exceptions raised by Ruby
  predicate methods instead of returning validation failures.
- Added generated predicate ownership declarations and explicit rule-context
  visibility for the supported contract API.
- Improved native schema, coercion, predicate, and rule-dependency execution
  while preserving the documented compatibility subset.
- Added Rust 1.75 MSRV verification, source-gem package auditing, and public
  API documentation checks.

## 0.1.0.pre4 — 2026-08-12

- Improved native coercion and declared-key validation performance.
- Fixed predicate-block arity validation and range-predicate message
  interpolation.
- Improved native structured error reporting and stability coverage for hostile
  Ruby inputs.
- Refined the public schema, contract, result, values, and message data types
  without broadening the documented compatibility surface.

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
