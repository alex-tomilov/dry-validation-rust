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

Security releases and advisories remain subject to maintainer approval. No
report grants permission to publish a gem, create a tag, or disclose private
project information.
