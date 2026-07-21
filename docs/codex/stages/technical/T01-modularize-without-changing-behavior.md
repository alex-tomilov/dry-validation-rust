# Codex stage T01: modularize without changing behavior

**Priority:** P1  
**Dependencies:** None

## Assignment

Split oversized Rust and Ruby implementation files into ownership-based modules
without changing public or compatibility behavior. Audit the current tree first;
the roadmap's sample filenames and code are design sketches, not patches.

## Work

- Separate native plan, processing, coercion, predicate, error, and FFI entry
  concerns where the current code supports those boundaries.
- Separate Ruby schema definition/building concerns only where cohesion improves.
- Keep loading order, constants, visibility, and generated extension paths stable.
- Move existing tests with their behavior; do not create tests for file layout.

## Files

Likely `ext/dry_validation_rust/src/`, `lib/dry/validation/rust/`, and focused
behavior tests. Determine the exact set from current code.

## Scope control

No new DSL, predicate, coercion, lint regime, documentation site, or optimization.
Do not reproduce unsafe roadmap examples using `eval`, broad `.ok()`, default
fallbacks, unchecked Ruby conversions, or silent unknown-predicate success.

## Acceptance criteria

- Focused and full behavior suites are unchanged and green.
- Rust/Ruby module responsibilities are clear without circular loading.
- No public constant, method, error, normalized value, or loading mode changes.
- The diff contains no file-layout or doc-comment metadata tests.
