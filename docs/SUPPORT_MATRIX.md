# Support matrix

This matrix describes the public support target for each planned gem line. It
does not widen the implemented API surface; feature support remains documented
in [COMPATIBILITY.md](COMPATIBILITY.md).

## Versioned targets

| Gem line | Ruby    | Rust MSRV | Platforms                                           | Upstream reference                           | Status |
| -------- | ------- | --------- | --------------------------------------------------- | -------------------------------------------- | ------ |
| 0.1.x    | 3.3-3.5 | 1.75      | Source build; four precompiled gems in `0.1.0.pre5` | `dry-validation` 1.11.1, `dry-schema` 1.16.0 | alpha  |
| 0.2.x    | 3.3-3.5 | 1.75      | Planned Tier-1 gems; source-build fallback          | pinned before beta                           | beta   |

## Released 0.1.x native gems

`0.1.0.pre5` includes the following precompiled native-gem assets. These are
published pre-release artifacts; they do not by themselves establish a Tier 1
support commitment.

| Gem platform     | Native gem availability   |
| ---------------- | ------------------------- |
| `x86_64-linux`   | Published in `0.1.0.pre5` |
| `aarch64-linux`  | Published in `0.1.0.pre5` |
| `x86_64-darwin`  | Published in `0.1.0.pre5` |
| `arm64-darwin`   | Published in `0.1.0.pre5` |
| `x64-mingw-ucrt` | No precompiled gem yet    |

## 0.2.x platform matrix

These are the planned Tier 1 targets for `0.2.x`, not a claim of current
platform support. A target becomes Tier 1 only after CI cross-builds its gem
with `rake-compiler-dock`, passes an installed-gem load and contract smoke test
on a matching native runner, and a precompiled gem is published for it.

| Gem platform     | Ruby ABI | Support level  | Notes                           |
| ---------------- | -------- | -------------- | ------------------------------- |
| `x86_64-linux`   | GNU      | Planned Tier 1 | Primary server target           |
| `aarch64-linux`  | GNU      | Planned Tier 1 | ARM servers, including Graviton |
| `x86_64-darwin`  | N/A      | Planned Tier 1 | Intel Macs                      |
| `arm64-darwin`   | N/A      | Planned Tier 1 | Apple Silicon                   |
| `x64-mingw-ucrt` | UCRT     | Planned Tier 1 | Windows 10 and later            |

All other CRuby platforms are best effort through the source gem. A source
build requires the toolchain documented in the [README](../README.md#source-build)
and may require local platform-specific fixes; it does not imply a precompiled
gem or matching CI coverage.

## Support policy

- `Dry::Validation::Rust::Contract` is the primary supported API for the
  `0.1.x` line.
- Familiar dry-validation-style syntax is supported only for the compatible
  subset covered by tests and documented in [COMPATIBILITY.md](COMPATIBILITY.md).
- Exact compatibility mode owns upstream-like require paths and constants. It
  is deprecated, excluded from the support promise, and remains temporarily
  available only for migration. It must run in a process isolated from upstream
  `dry-validation` and `dry-schema`; use the
  [exact-mode migration guide](MIGRATION_FROM_EXACT_MODE.md) to move to the
  supported side-by-side namespace.
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

The compatibility shim is deprecated and excluded from the public API
compatibility guarantee. Its removal timeline will be set in a separately
scoped breaking-release implementation; until then, users should follow the
[exact-mode migration guide](MIGRATION_FROM_EXACT_MODE.md). Changes to its
documented support status still follow this policy when they remove a listed
runtime or platform target. A change to the Rust crate's internal
implementation is not an ABI break by itself; the ABI rule applies when it
changes which CRuby/Magnus ABI combinations the gem supports or requires users
to rebuild incompatible native artifacts.

## Exact-mode decision

The current gem contains the deprecated exact compatibility shim while users
migrate. The project will not extract it into a separate gem or stabilize its
namespace isolation. The maintained API is
`Dry::Validation::Rust::Contract`; see [ADR-005](adr/005-exact-mode.md) and
the [exact-mode migration guide](MIGRATION_FROM_EXACT_MODE.md).
