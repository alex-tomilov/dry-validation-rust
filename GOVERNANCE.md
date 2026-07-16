# Governance

## Project status and maintainer

`dry-validation-rust` is an independent, single-maintainer project. Alexey
Tomilov is the current maintainer and has final responsibility for technical
direction, merges, releases, security advisories, and repository
administration.

This governance model describes the current project; it does not imply a
foundation, steering committee, or multi-maintainer organization.

## Decision making

Routine changes are decided through issue and pull-request discussion. The
maintainer considers correctness, compatibility evidence, FFI safety,
maintenance cost, performance evidence, and alignment with the documented
product scope.

When consensus is not reached, the maintainer makes the final decision and
records material tradeoffs in the issue, pull request, architecture
documentation, or changelog as appropriate.

## Compatibility philosophy

`Dry::Validation::Rust::Contract` is the primary supported API. Familiar
dry-validation-style behavior is supported only where it is documented and
tested against pinned upstream releases. Exact compatibility mode remains
experimental and process-isolated from upstream gems.

Unsupported behavior must fail loudly. Compatibility claims require executable
evidence; performance claims require reproducible measurements. The project
will not silently widen its supported DSL or weaken tests to hide a mismatch.

## Breaking changes

Breaking changes should start with a public issue describing the affected
surface, migration path, compatibility evidence, and release impact. During
the alpha period, breaking changes may occur in prereleases, but they must be
intentional and documented.

Once a stable line exists, its deprecation and support policy will be defined
before release. This file does not create a stability promise beyond the
current support matrix.

## Branches and releases

`main` is the sole long-lived integration and release branch. Contributors use
short-lived feature branches and merge them through pull requests targeting
`main`. Releases are tagged from tested commits on `main`.

The repository previously accumulated work on `develop` while `main` remained
the GitHub default branch. After this policy is merged, the owner should:

1. promote the complete tested `develop` history to `main`;
2. verify that open pull requests target `main`;
3. update existing managed roadmap issue links from `develop` to `main` and
   verify that they resolve;
4. configure the protection target below on `main`;
5. retire `develop` after confirming that it contains no unique commits, open
   work, or managed roadmap links.

No new long-lived integration branch should be introduced unless release
management evidence shows that the main-only model is insufficient.

### Branch protection target

The owner configures repository settings manually. Protection for `main`
should:

- require pull requests for normal changes;
- require the status checks listed below to pass;
- block force pushes;
- block branch deletion;
- require conversation resolution;
- use squash merge for a linear history;
- leave signed commits or tags optional until a separate policy adopts them.

The exact required status-check contexts are:

| Workflow | Required check context |
| --- | --- |
| CI | `Ruby 3.3 on ubuntu-latest` |
| CI | `Ruby 3.3 on macos-latest` |
| CI | `Ruby 3.4 on ubuntu-latest` |
| CI | `Ruby 3.4 on macos-latest` |
| CI | `Ruby 3.5 on ubuntu-latest` |
| CI | `Ruby 3.5 on macos-latest` |
| CI | `Rust quality on 1.85.0` |
| CI | `Rust quality on stable` |
| CI | `Loading modes and installed gem` |
| Compatibility | `Pinned upstream preflight` |
| Package | `Source gem audit` |
| Security | `Dependency audit` |
| Security | `CodeQL` |

These names are part of the repository governance contract. Rename a required
workflow job only in the same pull request that updates this table and the
branch-protection configuration.

Only the maintainer may authorize a gem publication, release tag, GitHub
release, or security advisory. Passing CI does not itself authorize a release.

## Adding maintainers

Additional maintainers may be invited after sustained, trustworthy
contributions across code review, compatibility work, security-sensitive
changes, documentation, and support. Access should be granted incrementally
and follow least privilege. Any change to release or security authority will
be documented publicly.

## Relationship to dry-rb

This project is independent from dry-rb and its maintainers. It is not an
official dry-rb project, and its compatibility and support statements apply
only to `dry-validation-rust`. Upstream project names are used to describe the
API reference and comparison target.
