# Dependency and supply-chain policy

This project treats dependency and lockfile changes as reviewed code changes.
The Ruby and Rust lockfiles are intentionally committed:

- `Gemfile.lock` preserves the development and CI Ruby dependency set.
- `ext/dry_validation_rust/Cargo.lock` preserves the native extension build
  dependency set.

Automated dependency update pull requests are enabled with Dependabot for
Bundler, Cargo, and GitHub Actions. Routine development dependency updates may
be grouped, but native bridge updates involving `magnus`, `rb-sys`, `rb_sys`,
or `rake-compiler-dock` are isolated because they can change Ruby/Rust FFI
build and runtime behavior.

## Review policy

- Lockfile updates must go through ordinary pull request review.
- CI must pass before merging dependency updates.
- Native bridge updates require extra attention to native compilation,
  installed-gem smoke tests, Ruby object lifetime assumptions, and supported
  Ruby/Rust versions.
- GitHub Actions updates must preserve explicit permissions and must not add
  publish credentials to pull-request jobs.

## Audit policy

The security workflow runs:

- `bundler-audit` for Ruby advisories;
- `cargo audit --deny warnings` for Rust advisories;
- `cargo vet --locked` for reviewed Rust dependency provenance;
- lockfile presence and locked Cargo build checks;
- CodeQL for Ruby.

Audit failures should be fixed by updating, removing, or replacing the affected
dependency. If an advisory or warning cannot be fixed immediately, document a
temporary exception in this file before merging.

## Audit exceptions

There are no active audit exceptions.

Temporary exceptions must use this format and include an expiry date:

```text
- ID: advisory or warning identifier
  Dependency: package name and affected version
  Reason: why the finding is not immediately fixable
  Mitigation: what keeps users or maintainers protected meanwhile
  Owner: maintainer responsible for follow-up
  Expires: YYYY-MM-DD
```

Expired exceptions are treated as audit failures until renewed or resolved.

## Artifact provenance

The release workflow is prepared but has not yet been validated by a published
release. The `rubygems:push` workflow uses RubyGems trusted publishing instead of a
long-lived token. It signs every built source and native gem with keyless
Sigstore and stores the resulting bundles with the workflow artifacts. Configure
RubyGems.org to trust `.github/workflows/rubygems-push.yml` before its first
release.
