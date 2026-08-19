# Security policy

## Supported release lines

`dry-validation-rust` is currently an alpha project. Security fixes are
considered for the latest `0.1.x` prerelease and the current `main` branch on a
best-effort basis.

| Release line | Security support |
| --- | --- |
| Latest `0.1.x` prerelease | Best effort |
| Older prereleases | Upgrade required |
| Unreleased development branches | No separate backport promise |

The project does not yet promise long-term support or security backports.
Platform and runtime targets are listed in
[docs/SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md).

## Reporting a vulnerability

Do not open a public issue, discussion, or pull request for a suspected
vulnerability.

Use
[GitHub private vulnerability reporting](https://github.com/alex-tomilov/dry-validation-rust/security/advisories/new)
to send the report to the maintainer. If GitHub shows that private reporting is
unavailable, do not disclose the report publicly; contact the maintainer
through a private contact method listed on the maintainer's GitHub profile and
ask for a secure reporting channel.

Include:

- the affected gem version, commit, and loading mode;
- Ruby, Rust, OS, architecture, and source/native build details;
- a minimal reproducer or proof of concept;
- the expected and observed security boundary;
- impact, prerequisites, and known mitigations;
- whether the issue is already public or shared with anyone else;
- any preferred disclosure or credit details.

Do not include real credentials, private production data, or unnecessary
personal information.

## What to expect

The maintainer aims to acknowledge a complete report within seven calendar
days, but this is a target rather than an SLA. Triage may request additional
information or determine that the report is a correctness bug without a
security impact.

For an accepted vulnerability, the reporter and maintainer will coordinate on
impact, remediation, release timing, advisory text, and credit. Disclosure
should wait until a fix or practical mitigation is available, unless active
exploitation or another overriding public-interest concern requires a
different timeline.

## Coordinated disclosure and embargo

The project uses a 90-calendar-day embargo for public technical details after
a fixed version is released. During that period, the maintainer may publish a
minimal advisory and upgrade guidance, but will not publish a proof of concept
or detailed exploitation steps without coordinating with the reporter.

The embargo may end earlier only with the reporter's agreement, or when active
exploitation, an already-public disclosure, or another overriding
public-interest concern makes earlier disclosure necessary. At the end of the
embargo, the maintainer will publish the advisory through GitHub Security
Advisories when practical and credit the reporter if requested.

## Dependency-audit schedule

The [Security workflow](.github/workflows/security.yml) runs on pull requests,
pushes to `main` and `develop`, and every Monday. It runs `bundler-audit` for
Ruby dependencies and `cargo audit --deny warnings` for Rust dependencies.
Audit failures are handled under
[the dependency-security policy](docs/DEPENDENCY_SECURITY.md).

Security releases and advisories remain subject to maintainer approval. No
report grants permission to publish a gem, create a tag, or disclose private
project information.

## Gem signing and publication

Release gems are built only by the protected `rubygems:push` workflow. The
workflow signs every source and native gem with GitHub Actions OIDC and
Sigstore, then attaches the resulting `.sigstore.json` bundle alongside the
gem to the GitHub release.

RubyGems.org publication uses RubyGems Trusted Publishing through the same
OIDC identity; the repository does not keep a long-lived RubyGems API key for
this workflow. RubyGems Trusted Publishing must be configured on RubyGems.org
for `alex-tomilov/dry-validation-rust`, the `rubygems:push` workflow, and the
GitHub `release` environment before a release can publish.

The `release` environment is an approval boundary. Maintainers must review the
tag and generated artifacts before approving it. A test publication, when
needed, must use a separate RubyGems test-host trusted-publisher configuration
and must not change the production publisher or release environment.
