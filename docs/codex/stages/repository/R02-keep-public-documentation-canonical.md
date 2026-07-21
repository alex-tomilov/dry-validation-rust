# Codex stage R02: keep public documentation canonical

**Priority:** P1  
**Dependencies:** current supported scope from `T03`

## Assignment

Make the repository understandable with a small canonical documentation set.
Update claims from executable evidence and delete duplicated or speculative
material rather than expanding it.

## Work

- Keep README to identity/non-affiliation, maturity, safe quick start, major
  limitations, build requirements, and links.
- Keep architecture ownership/invariants, compatibility, support matrix,
  verification, roadmap, and release/version policy in one canonical location
  each; merge documents when audiences overlap.
- Add only runnable, maintained examples; label framework snippets illustrative.
- Record user-visible changes in the changelog after implementation, never in
  anticipation.

## Files

README and the smallest affected set under `docs/`; examples only when executed.

## Scope control

No requirement for YARD on every method, GitHub Pages, documentation coverage,
prose-substring tests, decorative badge wall, fabricated benchmark table, or a
document per roadmap bullet.

## Acceptance criteria

- Safe API and non-affiliation are immediately clear.
- Every public compatibility/performance/platform claim points to evidence.
- Information has one canonical home with links instead of copied matrices.
- Documentation tests are limited to executable examples or security/package
  semantics that cannot be verified more directly.
