# Codex gate G00: audit prerelease readiness

**Priority:** P0  
**Dependencies:** `T01–T04`, `R01–R03`

## Assignment

Audit the current repository for a safe public prerelease. Produce an evidence
table first, then implement only the smallest remaining blocker that fits one
reviewable pull request.

## Gate

- Safe namespace and independent/non-drop-in status are clear.
- Compiled plans, unsupported states, exception propagation, integer behavior,
  and FFI panic containment satisfy repository invariants.
- Supported claims have pinned differential evidence; robustness tests cover
  malformed plans, GC/concurrency boundaries, and clean loading.
- Canonical verification, CI/security checks, source package audit, and clean
  temporary installation pass.
- Version, changelog, release notes, toolchain requirements, rollback, and known
  limitations are accurate.

## Files

Only files required by the single selected blocker.

## Scope control

Do not treat documentation assertions or coverage percentage as evidence. Do not
publish a gem, create/push a tag, create a GitHub release, add credentials, or
change repository settings.

## Acceptance criteria

- Gate status distinguishes pass, missing evidence, and known failure.
- The selected blocker is fixed with focused tests and full verification.
- Remaining blockers are ordered and scoped without being implemented together.
- No external release action occurs.
