---
name: version-tag-suggestion
description: Recommend the next dry-validation-rust release version and Git tag from the changes since the latest release tag. Use for release-version planning; it does not prepare, create, or publish a release.
---

# Version Tag Suggestion

Recommend one release version and matching `v...` Git tag, or recommend no
release tag when the range has no release-relevant change. This is a planning
skill: do not edit version files, run `script/release`, create a tag, commit,
push, or publish.

## Establish the comparison range

- If the user supplies two refs or tags, inspect that exact `base..head`
  range. Otherwise, find the newest reachable release tag matching
  `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH.preN`, and compare it with
  `HEAD`. Ignore non-release tags such as `build-week-2026`.
- Confirm the baseline tag, its commit, the head commit, and whether the
  working tree is clean. A dirty tree is useful context but is not part of the
  tagged range; do not infer a version bump from uncommitted changes unless the
  user explicitly asks for that.
- Inspect both the non-merge commit subjects and the actual diff. Commit type
  is supporting evidence, never the sole basis for a version bump. Read the
  affected public Ruby API, compatibility/support documentation, changelog,
  packaging, and tests where they clarify observable behavior.
- Use `git diff --name-status BASE..HEAD`, `git log --no-merges --oneline
  BASE..HEAD`, and focused diffs. Do not treat a merge commit title as a change
  classification.

## Apply this project's version policy

Read `docs/SUPPORT_MATRIX.md`'s **Semantic versioning policy** before making
the recommendation. It is authoritative. Classify all changes, then choose the
largest applicable bump:

- **Minor:** a backwards-compatible Ruby predicate or schema feature; a newly
  supported precompiled platform; a higher documented Rust MSRV; or any
  breaking change to a supported public API, supported runtime/platform, or
  native ABI while the project is below 1.0.
- **Patch:** a backwards-compatible user-visible bug fix, security correction,
  documentation correction, or internal native implementation change that is
  release-worthy.
- **No tag:** tests, CI, tooling, benchmarks, project process, and internal
  documentation-only changes with no release-worthy user, package, support, or
  compatibility effect. If the evidence is ambiguous, say what must be checked
  instead of inflating the version.

For a `0.x.y` stable baseline, a breaking supported surface still bumps the
minor line. At `1.0.0` or later, use a major bump for that class of break.

## Preserve the release channel

Parse the baseline tag rather than assuming the version in the working tree is
already prepared for release.

- From a stable baseline, propose the normal SemVer result: patch, minor, or
  major.
- From `vX.Y.Z.preN`, preserve the existing prerelease channel. A patch-class
  release advances to `vX.Y.Z.pre(N+1)`. A minor or breaking-class release
  advances to `vX.(Y+1).0.pre1` before 1.0, or `v(X+1).0.0.pre1` at 1.0+.
- Do not propose a stable release from a prerelease baseline, or switch a
  stable baseline to a prerelease, unless the user explicitly requests that
  release-channel change.

If the proposed version is not greater than the baseline, stop and report the
inconsistency. Also compare the recommendation with
`lib/dry/validation/rust/version.rb`; a mismatch is expected before release
preparation, but should be called out because `script/release` makes the Ruby
and Cargo versions and the release tag agree.

## Report

Return a compact recommendation containing:

1. comparison range and commits considered;
2. classification and concise, diff-backed reasons;
3. recommended version and exact tag, or **no release tag**;
4. any uncertainty or required release-channel decision; and
5. a reminder that the result is only a recommendation and that
   `docs/RELEASE_CHECKLIST.md` governs later release preparation.

Do not claim release readiness or that verification has passed merely from the
version analysis.
