---
name: Compatibility Slice

description: >
  Implement one compatibility improvement against
  a pinned external library, protocol, API, or format.

  Capture reference behavior first,
  support the smallest compatible subset,
  and make unsupported variants fail explicitly.

  Do not use for broad feature development
  or speculative parity work.
---

# Skill: Compatibility slice

Use this skill to reproduce one behavior of an external library, protocol, API, format, or previous version.

## Workflow

1. Pin or identify the reference version/contract.
2. Capture one valid, one invalid, and one boundary case.
3. Compare observable behavior: values, types, errors, ordering, exceptions, side effects, and mutation where relevant.
4. Implement the smallest supported form.
5. Make adjacent unsupported forms fail explicitly.
6. Add differential or contract tests.
7. Document the exact support boundary in the existing compatibility location
   and add a concise entry under `Unreleased` in `CHANGELOG.md`. If the slice
   adds or changes a public Ruby API, also update its inline YARD documentation
   and run `bundle exec yard --fail-on-warning`. Describe only the
   differential behavior demonstrated by the fixture or contract evidence.
8. If Ruby files, tests, tooling, or CI configuration changed, run
   `bundle exec rubocop` before reporting completion; resolve or explicitly
   report any offenses.

## Rules

- Parsing or accepting syntax is not proof of compatibility.
- Do not normalize away semantic differences.
- Do not recreate a large dependency ecosystem for one edge case.
- Narrow support rather than silently approximate behavior.
- Do not claim full compatibility from a curated subset.

## Stop conditions

Stop when the slice requires a major external subsystem, undocumented behavior cannot be characterized,
or supported and unsupported forms cannot be distinguished safely.
