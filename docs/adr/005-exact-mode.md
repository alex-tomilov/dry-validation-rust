# ADR 005: Deprecate the exact-compatibility shim

## Status

Accepted on 2026-08-22.

## Context

The primary public API is the side-by-side
`Dry::Validation::Rust::Contract` namespace. The experimental exact mode also
ships `require "dry/validation"`, `require "dry/schema"`, and aliases such as
`Dry::Validation::Contract`. Those paths and constants are owned by upstream
`dry-validation` and `dry-schema`, so both implementations cannot safely run
in the same Ruby process. The shim detects some collisions and raises
`LoadError`, but it cannot make the two implementations co-installable.

The loader files themselves are small (three lines each in
`lib/dry-validation.rb` and `lib/dry-schema.rb`), but their compatibility
commitment is not: preserving upstream loading and constants requires ongoing
testing against the pinned `dry-validation` 1.11.1 / `dry-schema` 1.16.0
reference and any future version considered for support. The current shim also
exposes only a documented subset of the upstream API.

## Decision

Deprecate exact compatibility mode. Do not extract it into a separate gem and
do not stabilize its namespace isolation.

The maintained migration path is `require "dry/validation/rust"` and
`Dry::Validation::Rust::Contract`. A follow-up deprecation implementation will
set the release and migration timeline, warn users of the exact entrypoints,
and ultimately remove `lib/dry-validation.rb` and `lib/dry-schema.rb` in the
appropriate breaking release after public feedback has been reviewed.

## Consequences

- Future work has one supported namespace and no upstream require-path or
  constant collision surface.
- Existing exact-mode users need a documented migration to the side-by-side
  namespace before the removal release.
- The project avoids a second gem, its release cadence, package metadata, and
  compatibility test matrix without evidence that users need that option.
- The exact mode remains available unchanged until the separately scoped
  deprecation implementation is approved; this ADR does not remove it.

## Alternatives considered

- **Extract to `dry-validation-rust-compat`:** would make the collision-prone
  API opt-in and independently versioned, but creates a second package and
  preserves the same upstream compatibility and support burden. Reconsider
  only if discussion feedback establishes a concrete migration need.
- **Stabilize exact mode:** would retain a familiar migration surface, but Ruby
  cannot isolate identical require paths and constants from upstream in one
  process. Better checks cannot eliminate that fundamental conflict.

## Rollback plan

The decision has no runtime effect until its follow-up implementation. If
feedback shows that exact mode is necessary, keep the existing experimental
shim during the next release cycle and supersede this ADR with a narrowly
scoped extraction decision. If a released deprecation blocks migration, restore
the shim in the next compatible release while the extraction option is
evaluated.
