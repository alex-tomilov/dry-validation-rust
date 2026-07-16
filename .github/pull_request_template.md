## Summary

Describe the problem and the focused change.

## Design

Explain important design choices, rejected alternatives, and affected Ruby/Rust
ownership boundaries.

## API and compatibility

State the public API impact. For compatibility changes, include pinned upstream
versions and separate-process comparison results.

## Verification

List the exact commands and results.

- [ ] Added or updated regression tests where applicable.
- [ ] Ran relevant focused Ruby/Rust checks.
- [ ] Ran `script/verify`.
- [ ] Confirmed supported behavior still fails loudly when input or DSL is unsupported.
- [ ] Added reproducible benchmark evidence for any performance claim.

## Documentation and packaging

- [ ] Updated `CHANGELOG.md` for a user-visible change, or explained why no entry is needed.
- [ ] Updated relevant support, compatibility, architecture, or verification documentation.
- [ ] Did not commit generated native binaries, `.gem` packages, Cargo `target` output, credentials, or unrelated artifacts.
- [ ] Did not publish a gem, create/push a tag, finalize a release, or change repository settings.

## Risks and rollback

Describe remaining limitations, operational risks, and the simplest rollback.
