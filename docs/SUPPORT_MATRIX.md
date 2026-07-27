# Support matrix

This matrix describes the public support target for each planned gem line. It
does not widen the implemented API surface; feature support remains documented
in [COMPATIBILITY.md](COMPATIBILITY.md).

## Versioned targets

| Gem line | Ruby    | Rust MSRV | Platforms                                                                  | Upstream reference                           | Status |
| -------- | ------- | --------- | -------------------------------------------------------------------------- | -------------------------------------------- | ------ |
| 0.1.x    | 3.3-3.5 | 1.85      | Source build, tested matrix recorded in [VERIFICATION.md](VERIFICATION.md) | `dry-validation` 1.11.1, `dry-schema` 1.16.0 | alpha  |
| 0.2.x    | TBD     | TBD       | Native gems under evaluation                                               | pinned before beta                           | beta   |

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

## Product architecture note

The current gem contains both the safe namespace and the exact compatibility
shim. If the exact shim becomes expensive to maintain or its collision surface
creates user confusion, the intended split is:

```text
dry-validation-rust
dry-validation-rust-compat
```

No split is planned for `0.1.x` without concrete maintenance evidence.
