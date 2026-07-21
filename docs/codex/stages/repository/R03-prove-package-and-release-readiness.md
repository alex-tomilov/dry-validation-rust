# Codex stage R03: prove package and release readiness

**Priority:** P0/P1  
**Dependencies:** `R01`, `R02`, `T04`

## Assignment

Prove source-gem installation first, then add native artifacts one platform at a
time. Release automation must support safe dry runs and trusted publishing, but
this stage never publishes.

## Work

- Maintain one version source, accurate gemspec metadata, and an allow/deny
  package-content audit.
- Build, install, require, and execute the source gem in a clean temporary gem
  home.
- For native gems, verify Ruby ABI, platform/libc tag, linkage, artifact contents,
  and no-Rust installation on each advertised platform.
- Keep release verification separate from protected publication permissions and
  prefer short-lived trusted publishing over API-key files.
- Define versioning, rollback, failed-release, and source fallback behavior.

## Files

Gemspec, package tasks, release/native workflows, support/release docs, and clean
installation smoke tests.

## Scope control

Do not copy roadmap examples that write `~/.gem/credentials`, push from CI,
publish, tag, create a release, or advertise an untested artifact.

## Acceptance criteria

- Source package contents and clean install are executable and green.
- Each native platform claim has a successful artifact smoke test.
- Release automation can dry-run without publication credentials.
- No generated gem, native library, credential, tag, or release is committed.
