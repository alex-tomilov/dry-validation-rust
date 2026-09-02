---
name: Release Readiness

description: >
  Verify that the project is ready for release.

  Validate supported behavior,
  packaging,
  installation,
  compatibility,
  platform support,
  changelog,
  and release evidence.

  Do not perform ordinary feature development.
---

# Skill: Release readiness

Use this skill only for an actual release candidate or explicit release-preparation task.

## Verify

- supported behavior and compatibility claims;
- changelog entries for user-visible changes, reconciled with the observable
  diff since the previous release tag;
- package contents and clean installation;
- supported environment/platform matrix;
- security-sensitive changes;
- migration or upgrade notes when required;
- reproducible version and build metadata;
- known limitations and rollback path.
- `bundle exec rubocop` passes when the release candidate includes Ruby source,
  tests, tooling, or CI configuration changes.
- `bundle exec yard --fail-on-warning` passes when the release candidate
  changes a public Ruby API or its YARD documentation.

## Rules

- Do not add release machinery during ordinary feature work.
- Do not advertise untested platforms or compatibility.
- Do not publish, tag, or create a remote release unless explicitly authorized.
- Prefer one concise release checklist over multiple certification documents.
