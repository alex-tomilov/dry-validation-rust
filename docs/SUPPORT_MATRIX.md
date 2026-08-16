# Support matrix

This matrix describes the public support target for each planned gem line. It
does not widen the implemented API surface; feature support remains documented
in [COMPATIBILITY.md](COMPATIBILITY.md).

## Versioned targets

| Gem line | Ruby    | Rust MSRV | Platforms                                          | Upstream reference                           | Status |
| -------- | ------- | --------- | -------------------------------------------------- | -------------------------------------------- | ------ |
| 0.1.x    | 3.3-3.5 | 1.75      | Source build; all CI workflows use the pinned MSRV | `dry-validation` 1.11.1, `dry-schema` 1.16.0 | alpha  |
| 0.2.x    | TBD     | TBD       | Native gems under evaluation                       | pinned before beta                           | beta   |

## Support policy

- `Dry::Validation::Rust::Contract` is the primary supported API for the
  `0.1.x` line.
- Familiar dry-validation-style syntax is supported only for the compatible
  subset covered by tests and documented in [COMPATIBILITY.md](COMPATIBILITY.md).
- Exact compatibility mode owns upstream-like require paths and constants. It
  is experimental, opt-in, and must run in a process isolated from upstream
  `dry-validation` and `dry-schema`.
- Runtime support means source builds and test coverage for the listed matrix,
  not precompiled native gems unless a later row explicitly says so.

## Semantic versioning policy

Releases follow [Semantic Versioning 2.0.0](https://semver.org/). The version
in `Dry::Validation::Rust::VERSION` is authoritative for the Ruby gem. A
release must use at least the bump shown below; multiple changes use the
largest applicable bump.

Before 1.0, a breaking change to a supported surface requires the next minor
line (for example, `0.1.x` to `0.2.0`). From 1.0 onward, it requires the next
major line. This preserves the `0.1.x` side-by-side API promise while keeping
the eventual stable-release policy conventional.

| Change type                                                                                      | Minimum version bump                         |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| Backwards-compatible bug fix, documentation correction, or internal native implementation change | Patch (`0.x.y`)                              |
| New backwards-compatible Ruby predicate or schema feature                                        | Minor (`0.x.0`)                              |
| Addition of a supported precompiled platform gem                                                 | Minor (`0.x.0`)                              |
| Increase to the documented Rust MSRV                                                             | Minor (`0.x.0`)                              |
| Removal of a supported platform, Ruby version, or precompiled platform gem                       | Next minor before 1.0; major from 1.0 onward |
| Incompatible change or removal in the documented public side-by-side Ruby API                    | Next minor before 1.0; major from 1.0 onward |
| Native ABI-incompatible change, including an incompatible Magnus or CRuby ABI support change     | Next minor before 1.0; major from 1.0 onward |

The compatibility shim is experimental and excluded from the public API
compatibility guarantee. Changes to its documented support status still follow
this policy when they remove a listed runtime or platform target. A change to
the Rust crate's internal implementation is not an ABI break by itself; the
ABI rule applies when it changes which CRuby/Magnus ABI combinations the gem
supports or requires users to rebuild incompatible native artifacts.

## Product architecture note

The current gem contains both the safe namespace and the exact compatibility
shim. If the exact shim becomes expensive to maintain or its collision surface
creates user confusion, the intended split is:

```text
dry-validation-rust
dry-validation-rust-compat
```

No split is planned for `0.1.x` without concrete maintenance evidence.
