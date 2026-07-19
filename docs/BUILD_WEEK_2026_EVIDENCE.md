# OpenAI Build Week 2026 evidence ledger

This page gives judges a repository-backed distinction between the
pre-existing `dry-validation-rust` prototype and work added during OpenAI
Build Week 2026. The
[official rules](https://openai.devpost.com/rules) require pre-existing
projects to distinguish prior work from meaningful extensions made with Codex
and/or GPT-5.6 during the submission period and to provide dated evidence.
Git history is the authority for the code boundary below; conversations and
screenshots supplement it but do not replace it.

## 1. Submission identity

- Project: `dry-validation-rust`
- Intended track: Developer Tools
- Repository: <https://github.com/alex-tomilov/dry-validation-rust>
- Submission branch: `feature/build-week-2026`
- Committed ledger scope: through `65dd9cd` on July 19, 2026
- Submission-period boundary: July 13, 2026 at 9:00 a.m. Pacific Daylight
  Time (`2026-07-13T16:00:00Z`)

> **Pre-existing-project warning:** this repository and its feasibility
> prototype predate the submission-period boundary. Only later work is Build
> Week work. The existence of a post-boundary commit does not by itself prove
> eligibility; the official rules and the complete evidence package remain
> authoritative.

## 2. Pre-existing baseline

The baseline was derived from the active branch with:

```bash
git log --before='2026-07-13T16:00:00Z' -1 \
  --date=iso-strict --pretty=fuller
```

- Full SHA:
  [`6e986c164ddd7e9fab5854c81fa300c5df898476`](https://github.com/alex-tomilov/dry-validation-rust/commit/6e986c164ddd7e9fab5854c81fa300c5df898476)
- Author timestamp: `2026-07-13T19:34:14+05:00`
  (`2026-07-13T14:34:14Z`)
- Committer timestamp: `2026-07-13T19:34:14+05:00`
  (`2026-07-13T14:34:14Z`)
- Subject:
  `Merge pull request #1 from alex-tomilov/feature/rust-backed-validation-engine`
- Merge-message body: `feat: add Rust-backed dry-validation prototype`

`git show --stat` and the tree at this commit show that the baseline already
contained the hybrid Ruby/Rust runtime: the Ruby contract DSL and rule layer,
the Rust native schema engine, safe and exact loading entrypoints, coercion,
nested validation, predicates, results/messages, tests, a benchmark script,
an example, source-gem packaging, and the initial architecture,
compatibility, feasibility, verification, changelog, license, and notice
documents. The merge introduced 48 files and 4,201 lines relative to its
first parent. None of those prototype capabilities is presented here as Build
Week work.

Both baseline timestamps are 1 hour, 25 minutes, and 46 seconds before the
official UTC boundary. There is no author/committer timestamp ambiguity for
this commit.

## 3. Build Week commit ledger

This table contains every post-boundary commit reachable from
`feature/build-week-2026` through committed ledger head `65dd9cd`. It uses
committer timestamps in UTC and orders commits chronologically. Author and
committer timestamps were checked with `%aI` and `%cI`; they identify the same
instant for every row. GitHub-created merge commits have a GitHub committer
identity, but no conflicting date. Uncommitted work is not evidence in this
ledger.

Both important constituent commits and their two-parent merge commits are
listed. This deliberately duplicates the high-level addition in merge rows:
the constituent commit identifies the authored diff, while the merge records
when that work entered the integration branch. The evidence column identifies
repository artifacts, not a claim that every historical CI job passed.

| Commit                                                                                                           | Timestamp              | Area                  | Concrete addition                                                                                                                               | Evidence/verification                                                                                                      |
| ---------------------------------------------------------------------------------------------------------------- | ---------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| [`ad2aff1`](https://github.com/alex-tomilov/dry-validation-rust/commit/ad2aff143cca17691ca3546455f57455dd7a1fcb) | `2026-07-15T15:40:29Z` | Codex workflow        | Added repository instructions and four focused review/diagnosis skills.                                                                         | `AGENTS.md`, `.agents/skills/`, and `docs/codex/README.md`                                                                 |
| [`ffac8cc`](https://github.com/alex-tomilov/dry-validation-rust/commit/ffac8cc52edb63e2d68abc3d38030a69b4e85024) | `2026-07-15T15:53:33Z` | Roadmap               | Added 31 technical, repository, and release-gate stage specifications.                                                                          | `docs/codex/stages/` tree and commit stat                                                                                  |
| [`48ccb7b`](https://github.com/alex-tomilov/dry-validation-rust/commit/48ccb7be2376b3f8e2154751336d8da35b843591) | `2026-07-15T16:00:09Z` | Integration           | Merged PR #2, integrating `ad2aff1` and `ffac8cc`.                                                                                              | Two-parent merge; second parent `ffac8cc`                                                                                  |
| [`29846e7`](https://github.com/alex-tomilov/dry-validation-rust/commit/29846e7ad72003c16f5afc320c03d9bea9e3cdff) | `2026-07-15T16:20:16Z` | Baseline verification | Added the canonical verification entrypoint, 12 JSON behavior fixtures, a machine-readable benchmark smoke, and verification/package hardening. | `script/verify`, `script/benchmark-smoke`, `test/baseline_fixture_test.rb`, and `test/fixtures/baseline/`                  |
| [`fa7cf3e`](https://github.com/alex-tomilov/dry-validation-rust/commit/fa7cf3ed205b0da95a04ec18e637553c5f818242) | `2026-07-15T16:24:36Z` | Integration           | Merged PR #3, integrating the baseline-verification work.                                                                                       | Two-parent merge; second parent `29846e7`                                                                                  |
| [`4bdee10`](https://github.com/alex-tomilov/dry-validation-rust/commit/4bdee101cf3c8cb1399f295ade94d9f50b5ff3e7) | `2026-07-15T16:34:27Z` | Product scope         | Defined the safe primary API, conservative product positioning, and version/platform support matrix.                                            | `README.md`, `docs/SUPPORT_MATRIX.md`, `docs/COMPATIBILITY.md`, and `test/documentation_test.rb`                           |
| [`0212847`](https://github.com/alex-tomilov/dry-validation-rust/commit/021284700f055881320f8ea1b74c4395e73380fc) | `2026-07-15T16:36:49Z` | Integration           | Merged PR #4, integrating the product-scope work.                                                                                               | Two-parent merge; second parent `4bdee10`                                                                                  |
| [`a9835c2`](https://github.com/alex-tomilov/dry-validation-rust/commit/a9835c20870a6b5c9b8f2c65c2dc3f3fcc811b03) | `2026-07-16T13:10:03Z` | Packaging             | Added public gem metadata and a source-package content/install audit.                                                                           | `dry-validation-rust.gemspec`, `Rakefile`, and `test/package_metadata_test.rb`                                             |
| [`312ff4f`](https://github.com/alex-tomilov/dry-validation-rust/commit/312ff4f40158fb721bbc1fc294ed6e9c29c15aac) | `2026-07-16T13:14:53Z` | Integration           | Merged PR #5, integrating package metadata and audit work.                                                                                      | Two-parent merge; second parent `a9835c2`                                                                                  |
| [`88c7810`](https://github.com/alex-tomilov/dry-validation-rust/commit/88c78104755882fe277b845c54288fa0c4914bc9) | `2026-07-16T13:25:04Z` | CI                    | Added Ruby/Rust CI, compatibility preflight, security audit, package audit, and bounded fuzz-preflight workflows.                               | `.github/workflows/`, `test/ci_workflows_test.rb`, and `docs/VERIFICATION.md`                                              |
| [`0b49b86`](https://github.com/alex-tomilov/dry-validation-rust/commit/0b49b8696a55fce2917aeee94facff6ab86955d1) | `2026-07-16T13:36:14Z` | Package CI fix        | Exposed the installed `rb_sys` library path to the isolated native-extension package build.                                                     | `Rakefile` and `test/package_metadata_test.rb`                                                                             |
| [`86cc076`](https://github.com/alex-tomilov/dry-validation-rust/commit/86cc07655df1394f35caca7db3871b7fc2a93d61) | `2026-07-16T13:45:37Z` | Security CI fix       | Pinned `cargo-audit` 0.22.1 for the dependency-audit job.                                                                                       | `.github/workflows/security.yml` and `test/ci_workflows_test.rb`                                                           |
| [`1414e2d`](https://github.com/alex-tomilov/dry-validation-rust/commit/1414e2dfd6705cd57f2b0681cc3e12bd02876904) | `2026-07-16T13:58:37Z` | Package CI fix        | Canonicalized the temporary gem-home path for macOS installed-package checks.                                                                   | `Rakefile` and `test/package_metadata_test.rb`                                                                             |
| [`a2d5b60`](https://github.com/alex-tomilov/dry-validation-rust/commit/a2d5b60d4ed177103263486453da223145ffd1ff) | `2026-07-16T14:10:51Z` | Ruby 3.5 CI fix       | Added `ostruct` as a development dependency for Rake boot on Ruby 3.5.                                                                          | `dry-validation-rust.gemspec`, `Gemfile.lock`, and `test/package_metadata_test.rb`                                         |
| [`0d58f75`](https://github.com/alex-tomilov/dry-validation-rust/commit/0d58f75b1e3fc458d16e2069d2f1c87e7c0a5601) | `2026-07-16T14:19:27Z` | Integration           | Merged PR #6, integrating the CI matrix and its four follow-up fixes.                                                                           | Two-parent merge; second parent `a2d5b60`                                                                                  |
| [`808b0f3`](https://github.com/alex-tomilov/dry-validation-rust/commit/808b0f377317b2b49468b4c0570be7207fcdc452) | `2026-07-16T14:29:22Z` | Supply chain          | Added Dependabot policy, dependency-version capture, and Ruby/Rust audit policy.                                                                | `.github/dependabot.yml`, `docs/DEPENDENCY_SECURITY.md`, `Rakefile`, and `test/supply_chain_test.rb`                       |
| [`49deb39`](https://github.com/alex-tomilov/dry-validation-rust/commit/49deb39e8aa1bc131d08613fea9708ab63579536) | `2026-07-16T14:35:42Z` | Integration           | Merged PR #7, integrating dependency and supply-chain policy.                                                                                   | Two-parent merge; second parent `808b0f3`                                                                                  |
| [`cb558e1`](https://github.com/alex-tomilov/dry-validation-rust/commit/cb558e1ecbb06bf55b5ba95a1e7370b173b21eed) | `2026-07-16T14:49:38Z` | Community health      | Added contribution, governance, security, support, conduct, issue, and pull-request policy files.                                               | Root policy documents, `.github/ISSUE_TEMPLATE/`, and `test/community_health_test.rb`                                      |
| [`5178d0c`](https://github.com/alex-tomilov/dry-validation-rust/commit/5178d0cecd7ebb373479597d9bf8528d91feb05d) | `2026-07-16T14:55:23Z` | Integration           | Merged PR #8, integrating community-health work.                                                                                                | Two-parent merge; second parent `cb558e1`                                                                                  |
| [`b1e61b0`](https://github.com/alex-tomilov/dry-validation-rust/commit/b1e61b07709043581d883ed14cba31233c6c7861) | `2026-07-16T15:37:40Z` | Project management    | Added roadmap/milestone policy, issue taxonomy, declarative GitHub metadata, and a dry-run-first synchronizer.                                  | `docs/PROJECT_MANAGEMENT.md`, `.github/project-management.yml`, `script/sync-github-project-management`, and focused tests |
| [`0605875`](https://github.com/alex-tomilov/dry-validation-rust/commit/0605875fa8acddf772d0f7d60071770c45709f77) | `2026-07-16T15:47:47Z` | Integration           | Merged PR #34, integrating project-management work.                                                                                             | Two-parent merge; second parent `b1e61b0`                                                                                  |
| [`d59086b`](https://github.com/alex-tomilov/dry-validation-rust/commit/d59086bee12780a4ef962e3ce63450b7bd30c2dd) | `2026-07-19T14:44:45Z` | Build Week evidence   | Added the pre-existing baseline, commit/session evidence ledger, and read-only audit helper.                                                     | `docs/BUILD_WEEK_2026_EVIDENCE.md` and `script/build-week-evidence`                                                        |
| [`65dd9cd`](https://github.com/alex-tomilov/dry-validation-rust/commit/65dd9cd7641d66af73eb8af82086aaf0790857d0) | `2026-07-19T15:07:09Z` | Judge demo            | Added an asserted safe-namespace order demo with human/JSON output and a README Build Week collaboration summary.                               | `examples/build_week_order_contract.rb`, `script/demo`, focused tests, and `README.md`                                     |

The all-refs inspection also found post-boundary commit
[`2dce1cc`](https://github.com/alex-tomilov/dry-validation-rust/commit/2dce1cc7faec4d8f8bbbd8a2371c010097ef0ddc)
on `feature/repository-governance`. It was not reachable from the active
submission branch at this stage, so it is not represented as submitted work
in the table.

## 4. GPT-5.6 and Codex contributions

The contribution boundary presented for judging is:

- GPT-5.6 was used as an architecture and repository-review partner.
- It helped analyze the feasibility prototype, identify
  correctness/compatibility/native-boundary risks, and create a staged
  maturity and refactoring roadmap.
- That roadmap covered verification, compatibility, benchmark methodology,
  packaging, CI, security, documentation, governance, and release readiness.
- Codex was then used to inspect the repository, implement accepted stages,
  run checks, and diagnose failures.
- The shipped validation runtime remains deterministic Ruby and Rust. It does
  not call GPT-5.6 and does not require an OpenAI API key.

The project owner supplied this
[shared ChatGPT conversation](https://chatgpt.com/share/6a5c38e4-c380-83ed-a4cb-ac221d42d905)
as contextual evidence. At the time this ledger was prepared, its public page
exposed the title “Rewriting Ruby Gem in Rust” but did not expose enough
information to verify a model name, conversation timestamp, or every later
implementation detail. It must therefore be paired with timestamped Codex
evidence and the Git ledger; it is not treated as standalone proof.

## 5. Codex session and commit evidence

The table below maps concrete roadmap work to Codex session IDs supplied by
the project owner and to the resulting Git history. Several stages were
completed in the same primary build thread; focused architecture stages used
separate sessions. The primary `/feedback` Session ID is also supplied through
the official submission form.

| Roadmap work                               | Codex session evidence                 | Resulting commits               |
| ------------------------------------------ | -------------------------------------- | ------------------------------- |
| Repository instructions and staged roadmap | `019f6b00-f639-7c82-a9f8-633407e9980f` | `ad2aff1`, `ffac8cc`, `48ccb7b` |
| `T00` reproducible baseline                | `019f6683-6455-7260-8760-903a6f87a26d` | `29846e7`, `fa7cf3e`            |
| `R00` product identity and scope           | `019f669a-0972-7eb1-8a5c-17651427cfd1` | `4bdee10`, `0212847`            |
| `R03` project metadata/package audit       | `019f6b00-f639-7c82-a9f8-633407e9980f` | `a9835c2`, `312ff4f`            |
| `R04` CI pipeline and follow-up diagnosis  | `019f6b00-f639-7c82-a9f8-633407e9980f` | `88c7810` through `0d58f75`     |
| `R05` dependency/supply-chain hygiene      | `019f6b00-f639-7c82-a9f8-633407e9980f` | `808b0f3`, `49deb39`            |
| `R02` community health                     | `019f6b00-f639-7c82-a9f8-633407e9980f` | `cb558e1`, `5178d0c`            |
| `R09` project planning                     | `019f6b00-f639-7c82-a9f8-633407e9980f` | `b1e61b0`, `0605875`            |

The two evidence types serve different purposes: Git establishes what changed
and when, while the session records show how Codex contributed to the work.
Neither is presented as independent proof of the model name or timestamp of
the contextual ChatGPT conversation described above.

## 6. Human decisions

The human author retained final product, engineering, scope, evidence, and
release decisions. In particular, the author retained:

- the Ruby/Rust responsibility boundary: Rust owns the immutable declarative
  schema plan and supported structural execution, while Ruby owns the DSL,
  arbitrary rule blocks, macros, options, context, and Ruby method semantics;
- `Dry::Validation::Rust` as the safe side-by-side primary API, with exact
  compatibility mode experimental and process-isolated;
- fail-loud behavior for unsupported types, modes, predicates, and DSL
  features;
- conservative compatibility claims tied to pinned, executable differential
  evidence;
- conservative, workload-specific performance claims tied to reproducible
  benchmarks and the explicit GVL limitation;
- the decision to keep GPT-5.6 out of the runtime and avoid any OpenAI API-key
  requirement;
- acceptance of the stages merged into this branch: `T00`, `R00`, `R02`,
  `R03`, `R04`, `R05`, and `R09`;
- postponement of the remaining technical, repository, and release-gate
  stages listed in `docs/PROJECT_MANAGEMENT.md` until their dependencies and
  evidence requirements are met.

At the ledger refresh point, no accepted-with-changes or rejected roadmap stage
was documented in the active branch history. `R01` had a separate branch
commit but was not accepted into the submission branch and is therefore not
counted as submitted work.

## 7. Independent verification

The boundary and ledger can be checked directly from the public repository:

```bash
git log --before='2026-07-13T16:00:00Z' -1 \
  --date=iso-strict --pretty=fuller
git log --since='2026-07-13T16:00:00Z' --reverse \
  --format='%H%x09%aI%x09%cI%x09%P%x09%s'
script/build-week-evidence
```

The helper is read-only: it reports the boundary, detected baseline, reachable
post-boundary commits, current head, working-tree state, and any remaining
Build Week placeholders. It makes no network calls and does not modify files,
commits, tags, or history.
