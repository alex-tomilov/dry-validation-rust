---
name: Documentation

description: >
  Update or create documentation only when
  public behavior, supported usage,
  compatibility,
  installation,
  or architecture truth has changed.

  Prefer updating existing documentation
  over creating new documents.

  Do not document completed implementation work
  that is already evident from code and tests.
---

# Skill: Documentation

Use this skill when documentation is the primary deliverable or when a behavior change makes existing documentation inaccurate.

## Choose the right location

- README/user guide: supported usage and first success path.
- API reference: public interfaces and parameters.
- Compatibility/support matrix: supported and unsupported boundaries.
- Architecture document: durable component ownership and data flow.
- ADR: durable cross-cutting decision.
- Changelog: user-visible change in a release.
- Issue/PR: temporary plan, discussion, or implementation context.
- Code comment: local non-obvious reasoning.

## Ruby API reference (YARD)

When adding or changing a public Ruby class, module, method, argument,
return value, raised error, or supported usage, update its adjacent YARD
documentation in the source file. Add documentation for a new public API; keep
the existing documentation accurate for a changed API.

For user-facing methods, document the purpose, parameters, return value, and
meaningful raised errors. Include an `@example` when it materially helps a user
call the API correctly. Do not add YARD comments for private implementation
details or churn documentation during an internal-only change.

After a Ruby public-API documentation change, run `bundle exec yard
--fail-on-warning`. Treat warnings as unfinished documentation. If YARD is not
available through the bundle, report that environment or dependency gap rather
than claiming the generated API reference was verified.

## Rules

- Update before creating.
- Link instead of duplicating.
- Describe current truth, not aspirational maturity.
- Label experimental behavior explicitly.
- Remove stale claims when implementation changes.
- Do not test prose or document layout unless it is machine-consumed.
- Do not write a document merely to prove a task was completed.

## Changelog

When a documentation change adds or materially changes user-facing installation,
operational, compatibility, or supported-usage guidance, inspect
`CHANGELOG.md`. If the repository records such changes under `Unreleased`, add
a concise entry that describes the user-visible documentation change. Do not
add a changelog entry for editorial-only corrections or internal-maintainer
documentation unless the repository's release policy requires one.

## Review questions

- Who needs this information?
- What decision or action does it enable?
- Is this the authoritative location?
- Will it become stale immediately?
- Can a test, type, schema, or error message express it more reliably?
