---
name: Migration
description: >
  Enable and verify one realistic migration path to dry-validation-rust with
  minimal user changes. Compare source and target behavior, preserve supported
  public semantics, make unsupported boundaries explicit, and avoid turning
  one migration task into a complete reimplementation of the source system.
---
# Skill: Migration

Use this skill for one concrete user migration path from the existing Ruby implementation or integration to dry-validation-rust.

## Core rule

A migration task should prove one realistic path end to end, not claim ecosystem-wide parity.

## Workflow

1. Define the source scenario:
   - current dry-validation usage;
   - supported contract/schema/rule shape;
   - framework/integration context when relevant.
2. Capture the existing behavior before changing the migration path.
3. Identify the minimum user-visible changes required by the intended migration.
4. Reuse already-supported compatibility behavior rather than reimplementing adjacent features.
5. Implement only the smallest missing support required for this migration when it is inseparable from the migration task.
6. Make unsupported adjacent behavior fail explicitly or remain clearly documented as unsupported.
7. Run the same representative scenario against the source/reference behavior and dry-validation-rust.
8. Add focused integration or differential coverage.
9. Update existing migration/compatibility documentation only when the
   supported boundary changed, and add a concise entry under `Unreleased` in
   `CHANGELOG.md` when the migration path adds or changes supported behavior.
   Describe the proven migration path, not broader upstream parity.
10. If Ruby source, tests, tooling, or CI configuration changed, run `bundle exec rubocop`.
11. If the migration changes a public Ruby API or its documentation, update YARD and run `bundle exec yard --fail-on-warning`.

## Rules

- Do not make unrelated application changes to force the migration to pass.
- Do not silently approximate dry-validation semantics.
- Do not recreate a large unsupported upstream subsystem for one migration.
- Do not broaden one successful scenario into a general compatibility claim.
- If a missing capability is independently useful and substantial, stop and route it to `compatibility` or `feature-delivery` as a separate task.

## Definition of done

- the declared migration scenario works;
- required user changes are minimal and explicit;
- source/reference and target semantics match for the supported path;
- unsupported boundaries remain explicit;
- focused and canonical verification passes.

## Delivery

Report the source scenario, required user changes, compatibility evidence, exact supported boundary, checks run, and deferred migration gaps.
