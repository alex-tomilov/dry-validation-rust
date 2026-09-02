# Deprecated exact compatibility mode

`require "dry/validation"` and `require "dry/schema"` are deprecated
exact-mode entrypoints. They remain temporarily available but cannot coexist
with upstream `dry-validation` or `dry-schema` in one Ruby process, because
they use the same require paths and constants.

Follow the [migration guide](migration.md) for the supported side-by-side
namespace, factory replacements, semantic-difference recipes, and verification
steps. The project does not promise full upstream compatibility; see
[ADR-005](adr/005-exact-mode.md) for the deprecation decision and
[SUPPORT_MATRIX.md](SUPPORT_MATRIX.md) for the supported API policy.
