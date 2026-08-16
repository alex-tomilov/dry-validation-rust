# Milestone F — Packaging and Platforms

Status: ⚪ Not started.
Last updated: 2026-07-29.

## Goal

Make installation and CI trustworthy across supported platforms.

## Tasks

### F-1: Expand CI Matrix

Minimum viable matrix:

| Axis  | Values                                          |
| ----- | ----------------------------------------------- |
| Ruby  | 3.3, 3.4, head                                  |
| OS    | ubuntu-latest, macos-latest (arm64)             |
| Rust  | stable, 1.75 (MSRV)                             |
| Build | source gem install, `rake compile`, `rake test` |

Add `cargo test` and `cargo clippy -- -D warnings` as a separate Rust CI job.
Add `cargo audit` and `bundle audit`.

### F-2: Precompiled Platform Gems

- Build precompiled gems for at least:
  - `x86_64-linux`
  - `arm64-darwin`
- Use `rake-compiler-dock` for cross-compilation.
- Publish to RubyGems as pre-release (`0.1.0.pre1`).

### F-3: Gemspec Metadata

Ensure the gemspec includes:

```ruby
spec.metadata = {
  "homepage_uri"    => "https://github.com/alex-tomilov/dry-validation-rust",
  "source_code_uri" => "https://github.com/alex-tomilov/dry-validation-rust",
  "changelog_uri"   => "https://github.com/alex-tomilov/dry-validation-rust/blob/main/CHANGELOG.md",
  "bug_tracker_uri" => "https://github.com/alex-tomilov/dry-validation-rust/issues",
  "rubygems_mfa_required" => "true"
}
```

### F-4: Developer Experience

- Add a `docker-compose.yml` or Devcontainer with Ruby 3.3 + Rust 1.75
  pre-configured. One command to a working REPL.
- Record a 2-minute terminal session (asciinema or GIF) showing:
  clone → compile → run example → see output. Embed in README.

### F-5: Changelog and Release Process

- Adopt Keep a Changelog format in `CHANGELOG.md`.
- Tag `v0.1.0.pre1` and push a pre-release gem to RubyGems.
- Document the release process in `docs/RELEASING.md`.

### F-6: RBS Type Signatures

Add RBS signatures in `sig/` for the public API surface:

- `Contract#call` → `Result`
- `Result` (all public methods: `success?`, `failure?`, `errors`, `to_h`, `[]`)
- `MessageSet#to_h` → `Hash[Array[Symbol], Array[String]]`
- `Message#text`, `Message#path`, `Message#predicate`
- `Schema.define`, `Schema.Params`, `Schema.JSON`

Even partial RBS is valuable. It enables editor autocomplete and catches
interface drift.

## Acceptance Criteria

- [ ] CI matrix covers Ruby 3.3/3.4/head × ubuntu/macos × stable/MSRV.
- [ ] Precompiled gems published for x86_64-linux and arm64-darwin.
- [ ] Gemspec has full metadata including `rubygems_mfa_required`.
- [ ] Devcontainer or docker-compose provides one-command onboarding.
- [ ] Terminal recording embedded in README.
- [ ] `CHANGELOG.md` in Keep a Changelog format.
- [ ] Pre-release gem published to RubyGems.
- [ ] RBS signatures exist for public API surface.
- [ ] `script/verify` passes on all matrix combinations.

## Dependencies

- Requires Milestone E (complete).
- Blocks Milestone G.
