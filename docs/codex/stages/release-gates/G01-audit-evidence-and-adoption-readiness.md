# Codex gate G01: audit evidence and adoption readiness

**Priority:** P0 for the milestone  
**Dependencies:** `G00`, `T05`, `R04`; `T06` remains optional/future

## Assignment

Audit whether the project has enough compatibility, package, performance, and
real-consumer evidence for broader adoption. Implement only one smallest blocker
after presenting the gate table.

## Gate

- The supported compatibility slice is broad enough for named use cases and all
  claims remain version-pinned.
- Source/native artifacts install on every advertised platform.
- Benchmarks are reproducible, semantically comparable, and include negative or
  neutral results.
- At least one maintained executable adoption path demonstrates rollback.
- Support/versioning/deprecation expectations match available maintainer and CI
  capacity.

## Files

Only files required by the selected blocker.

## Scope control

Do not require Rails, Hanami, YARD Pages, a badge wall, 90% coverage, GVL release,
or streaming merely for gate optics. Do not publish, tag, release, contact third
parties, or mutate repository settings.

## Acceptance criteria

- Gate evidence is executable or artifact-backed, not prose-only.
- One blocker at most is remediated in this run.
- Unsupported/platform/performance limitations remain explicit.
- Experimental `T06` work does not block the normal engine.
