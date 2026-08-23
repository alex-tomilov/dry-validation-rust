# Migrating from exact compatibility mode

Exact compatibility mode is deprecated. The supported API is the side-by-side
namespace exposed by `require "dry/validation/rust"`. The deprecated
`dry/validation` and `dry/schema` entrypoints remain available temporarily;
their removal release and timeline will be announced separately.

## Rename entrypoints and constants

Make these replacements in application code, initializers, and test setup:

| Deprecated exact mode              | Supported side-by-side API                     |
| ---------------------------------- | ---------------------------------------------- |
| `require "dry/validation"`         | `require "dry/validation/rust"`                |
| `require "dry/schema"`             | `require "dry/validation/rust"`                |
| `Dry::Validation::Contract`        | `Dry::Validation::Rust::Contract`              |
| `Dry::Validation.Contract { ... }` | `Dry::Validation::Rust.Contract { ... }`       |
| `Dry::Schema.Params { ... }`       | `Dry::Validation::Rust::Schema.Params { ... }` |
| `Dry::Schema.JSON { ... }`         | `Dry::Validation::Rust::Schema.JSON { ... }`   |
| `Dry::Schema.define { ... }`       | `Dry::Validation::Rust::Schema.define { ... }` |

For example:

```ruby
# Before
require "dry/validation"

class AgeContract < Dry::Validation::Contract
  params { required(:age).value(:integer) }
end

# After
require "dry/validation/rust"

class AgeContract < Dry::Validation::Rust::Contract
  params { required(:age).value(:integer) }
end
```

## Verify the migration

1. Remove the exact-mode require paths and `Dry::Validation`/`Dry::Schema`
   aliases from the application process.
2. Keep upstream `dry-validation` and `dry-schema` only where they are still
   needed; the side-by-side namespace can coexist with them.
3. Exercise production-shaped valid and invalid inputs. Compare output values,
   errors, paths, metadata, and raised exceptions with the prior behavior.
4. Check every used feature against [COMPATIBILITY.md](COMPATIBILITY.md).
   Unsupported behavior must be adapted explicitly rather than treated as a
   silent equivalent.

The project does not promise full upstream compatibility. See
[ADR-005](adr/005-exact-mode.md) for the deprecation decision and
[SUPPORT_MATRIX.md](SUPPORT_MATRIX.md) for the supported API policy.
