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

## Rules

- Update before creating.
- Link instead of duplicating.
- Describe current truth, not aspirational maturity.
- Label experimental behavior explicitly.
- Remove stale claims when implementation changes.
- Do not test prose or document layout unless it is machine-consumed.
- Do not write a document merely to prove a task was completed.

## Review questions

- Who needs this information?
- What decision or action does it enable?
- Is this the authoritative location?
- Will it become stale immediately?
- Can a test, type, schema, or error message express it more reliably?
