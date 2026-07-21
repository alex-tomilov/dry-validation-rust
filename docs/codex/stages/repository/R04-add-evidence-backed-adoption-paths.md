# Codex stage R04: add evidence-backed adoption paths

**Priority:** P2  
**Dependencies:** `G00`, representative `T03` compatibility coverage

## Assignment

Add adoption examples or optional framework adapters only for real consumer APIs
that can be maintained and tested. Begin with one standalone executable example.

## Work

- Keep standalone and JSON examples small and executable in CI.
- For Rails or Hanami, inspect the pinned framework's actual expectations and
  add a separately required adapter plus minimal integration fixture.
- Preserve optional dependencies and core loading without frameworks installed.
- Document migration, unsupported behavior, and rollback to upstream.

## Files

Optional adapter namespace, minimal integration fixtures, executable examples,
and concise usage links.

## Scope control

Illustrative controller snippets do not prove ActiveModel or Hanami compatibility.
Do not add full sample applications, generators, or outreach tasks before a
tested adapter need exists. Do not contact external maintainers without explicit
authorization.

## Acceptance criteria

- Every maintained example runs and asserts its result.
- Adapter dependencies are optional and isolated.
- Framework/version support matches CI evidence.
- No drop-in compatibility claim exceeds the exercised surface.
