# Release checklist

Run releases from a clean checkout on the intended commit. The script updates
the Ruby and Cargo versions (including the tracked Cargo lockfiles), starts a
dated changelog section, commits those changes, and creates the matching local
tag.

1. Add the release notes under `Unreleased` in `CHANGELOG.md`.
2. Run `script/verify`.
3. Run `script/release MAJOR.MINOR.PATCH` (or `MAJOR.MINOR.PATCH.preN`).
4. Inspect the generated commit and `vMAJOR.MINOR.PATCH` tag.
5. Push the commit and tag, then use the protected `rubygems:push` workflow.

## Usage examples

Create a normal release after the changelog entry and verification checks are
ready:

```bash
script/release 0.2.0
git show --stat --summary HEAD
git tag --points-at HEAD
```

This creates a `Release 0.2.0` commit and a local `v0.2.0` tag. Inspect both
before pushing them:

```bash
git push origin HEAD
git push origin v0.2.0
```

Create a prerelease with the supported `.preN` suffix:

```bash
script/release 0.2.0.pre1
git tag --points-at HEAD
```

This creates `v0.2.0.pre1`; the native Cargo package version is written as
`0.2.0-pre.1`, as required by Cargo's prerelease syntax.

The script creates only local Git history. It does not push a branch or tag,
publish a gem, or create a GitHub release.
