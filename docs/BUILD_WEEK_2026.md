# OpenAI Build Week 2026

> This file is finalized by `apply-reduction.sh` from the repository's real Git history. Review the generated baseline and commit table before submission.

## Project

`dry-validation-rust` is a hybrid Ruby/Rust validation prototype. Rust executes a supported immutable declarative schema plan; Ruby retains the public DSL, arbitrary business-rule blocks, macros, options, context, and Ruby-specific behavior.

The runtime is deterministic Ruby and Rust. It does not call GPT-5.6 and does not require an OpenAI API key.

## Pre-existing foundation

The repository predates the Build Week submission period, which began on **July 13, 2026 at 9:00 a.m. PDT** (`2026-07-13T16:00:00Z`).

- Baseline commit: `6e986c164ddd7e9fab5854c81fa300c5df898476`
- Baseline timestamp: `2026-07-13T19:34:14+05:00`
- Baseline subject: `Merge pull request #1 from alex-tomilov/feature/rust-backed-validation-engine`

At that point the repository already contained the feasibility prototype, native extension, safe namespace, supported Ruby DSL subset, rules, tests, architecture notes, compatibility notes, and an initial throughput benchmark. Those items are foundation work, not Build Week additions.

## Build Week additions

The reviewed submission work focused on making the existing prototype easier to evaluate and its claims easier to verify:

- a deterministic judge-facing contract demo;
- a multi-stage Docker judge image with a small command dispatcher;
- PR image smoke testing and restricted GHCR publication;
- post-publication verification of the pulled image by digest;
- reproducible comparative benchmark tooling and conservative reporting;
- clearer Build Week provenance, support limits, and judge instructions.

### Commit ledger

| Commit                                                                                                            | Timestamp                 | Change                                                                                         |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------- |
| [`ad2aff14`](https://github.com/alex-tomilov/dry-validation-rust/commit/ad2aff143cca17691ca3546455f57455dd7a1fcb) | 2026-07-15T20:40:29+05:00 | chore: add Codex project instructions and reusable skills                                      |
| [`ffac8cc5`](https://github.com/alex-tomilov/dry-validation-rust/commit/ffac8cc52edb63e2d68abc3d38030a69b4e85024) | 2026-07-15T20:53:33+05:00 | chore: add Codex files for next stages of roadmap of the repository                            |
| [`48ccb7be`](https://github.com/alex-tomilov/dry-validation-rust/commit/48ccb7be2376b3f8e2154751336d8da35b843591) | 2026-07-15T21:00:09+05:00 | Merge pull request #2 from alex-tomilov/feature/codex-project-instructions-and-reusable-skills |
| [`29846e7a`](https://github.com/alex-tomilov/dry-validation-rust/commit/29846e7ad72003c16f5afc320c03d9bea9e3cdff) | 2026-07-15T21:20:16+05:00 | chore: add reproducible baseline verification                                                  |
| [`fa7cf3ed`](https://github.com/alex-tomilov/dry-validation-rust/commit/fa7cf3ed205b0da95a04ec18e637553c5f818242) | 2026-07-15T21:24:36+05:00 | Merge pull request #3 from alex-tomilov/feature/baseline-verification                          |
| [`4bdee101`](https://github.com/alex-tomilov/dry-validation-rust/commit/4bdee101cf3c8cb1399f295ade94d9f50b5ff3e7) | 2026-07-15T21:34:27+05:00 | docs: define product identity and support scope                                                |
| [`02128470`](https://github.com/alex-tomilov/dry-validation-rust/commit/021284700f055881320f8ea1b74c4395e73380fc) | 2026-07-15T21:36:49+05:00 | Merge pull request #4 from alex-tomilov/feature/product-scope                                  |
| [`a9835c20`](https://github.com/alex-tomilov/dry-validation-rust/commit/a9835c20870a6b5c9b8f2c65c2dc3f3fcc811b03) | 2026-07-16T18:10:03+05:00 | chore: tighten gem metadata and add package audit                                              |
| [`312ff4f4`](https://github.com/alex-tomilov/dry-validation-rust/commit/312ff4f40158fb721bbc1fc294ed6e9c29c15aac) | 2026-07-16T18:14:53+05:00 | Merge pull request #5 from alex-tomilov/feature/project-metadata                               |
| [`88c78104`](https://github.com/alex-tomilov/dry-validation-rust/commit/88c78104755882fe277b845c54288fa0c4914bc9) | 2026-07-16T18:25:04+05:00 | ci: add Ruby, Rust, package, security, and preflight workflows                                 |
| [`0b49b869`](https://github.com/alex-tomilov/dry-validation-rust/commit/0b49b8696a55fce2917aeee94facff6ab86955d1) | 2026-07-16T18:36:14+05:00 | ci: try to fix the CI package-install failure in Loading modes and installed gem               |
| [`86cc0765`](https://github.com/alex-tomilov/dry-validation-rust/commit/86cc07655df1394f35caca7db3871b7fc2a93d61) | 2026-07-16T18:45:37+05:00 | ci: try to fix the Dependency audit failure                                                    |
| [`1414e2df`](https://github.com/alex-tomilov/dry-validation-rust/commit/1414e2dfd6705cd57f2b0681cc3e12bd02876904) | 2026-07-16T18:58:37+05:00 | ci: try to fix the macOS Ruby 3.3 on macos-latest package audit failure                        |
| [`a2d5b60d`](https://github.com/alex-tomilov/dry-validation-rust/commit/a2d5b60d4ed177103263486453da223145ffd1ff) | 2026-07-16T19:10:51+05:00 | ci: try to fix the Ruby 3.5 CI failure where bundle exec rake compile could not load ostruct   |
| [`0d58f75b`](https://github.com/alex-tomilov/dry-validation-rust/commit/0d58f75b1e3fc458d16e2069d2f1c87e7c0a5601) | 2026-07-16T19:19:27+05:00 | Merge pull request #6 from alex-tomilov/feature/ci-matrix                                      |
| [`808b0f37`](https://github.com/alex-tomilov/dry-validation-rust/commit/808b0f377317b2b49468b4c0570be7207fcdc452) | 2026-07-16T19:29:22+05:00 | chore: add dependency update and audit policy                                                  |
| [`49deb39e`](https://github.com/alex-tomilov/dry-validation-rust/commit/49deb39e8aa1bc131d08613fea9708ab63579536) | 2026-07-16T19:35:42+05:00 | Merge pull request #7 from alex-tomilov/feature/dependency-security                            |
| [`cb558e1e`](https://github.com/alex-tomilov/dry-validation-rust/commit/cb558e1ecbb06bf55b5ba95a1e7370b173b21eed) | 2026-07-16T19:49:38+05:00 | docs: add community health and support files                                                   |
| [`5178d0ce`](https://github.com/alex-tomilov/dry-validation-rust/commit/5178d0cecd7ebb373479597d9bf8528d91feb05d) | 2026-07-16T19:55:23+05:00 | Merge pull request #8 from alex-tomilov/feature/community-health                               |
| [`b1e61b07`](https://github.com/alex-tomilov/dry-validation-rust/commit/b1e61b07709043581d883ed14cba31233c6c7861) | 2026-07-16T20:37:40+05:00 | docs: add R09 project planning and GitHub synchronization                                      |
| [`0605875f`](https://github.com/alex-tomilov/dry-validation-rust/commit/0605875fa8acddf772d0f7d60071770c45709f77) | 2026-07-16T20:47:47+05:00 | Merge pull request #34 from alex-tomilov/feature/project-management                            |
| [`d59086be`](https://github.com/alex-tomilov/dry-validation-rust/commit/d59086bee12780a4ef962e3ce63450b7bd30c2dd) | 2026-07-19T19:44:45+05:00 | docs: establish Build Week evidence ledger                                                     |
| [`65dd9cd7`](https://github.com/alex-tomilov/dry-validation-rust/commit/65dd9cd7641d66af73eb8af82086aaf0790857d0) | 2026-07-19T20:07:09+05:00 | feat: add deterministic Build Week demo                                                        |
| [`fc254cfa`](https://github.com/alex-tomilov/dry-validation-rust/commit/fc254cfa8d685cc8aa3a8e24cd621249790e6fef) | 2026-07-19T20:14:39+05:00 | docs: polish BUILD_WEEK_2026_EVIDENCE.md                                                       |
| [`578c165b`](https://github.com/alex-tomilov/dry-validation-rust/commit/578c165b59d1f2cb65ab7e55a1d1670b950fdf7b) | 2026-07-19T21:07:23+05:00 | build: add precompiled Docker demo image                                                       |
| [`e4f7fdf3`](https://github.com/alex-tomilov/dry-validation-rust/commit/e4f7fdf389c84e2da77941ea70b63ae0c0a92d3a) | 2026-07-19T21:23:43+05:00 | ci: publish and smoke-test GHCR image                                                          |
| [`1a3512de`](https://github.com/alex-tomilov/dry-validation-rust/commit/1a3512de9761b1b1561bb9cfcb7016d9d06e13bc) | 2026-07-19T21:30:34+05:00 | ci: try to fix the Ruby 3.4 on macos-latest CI step                                            |
| [`53b0fb01`](https://github.com/alex-tomilov/dry-validation-rust/commit/53b0fb0188d2805a51b957baaedfa5a378c472c2) | 2026-07-19T21:37:04+05:00 | ci: try to fix the Ruby 3.5 on macos-latest CI step                                            |
| [`0c189d25`](https://github.com/alex-tomilov/dry-validation-rust/commit/0c189d252f478058963b53b4f0932d7c3461e59a) | 2026-07-19T21:56:09+05:00 | bench: add reproducible comparative evidence suite                                             |
| [`f26804df`](https://github.com/alex-tomilov/dry-validation-rust/commit/f26804df9fee543df33e531ad43b181c771c71ee) | 2026-07-20T17:21:19+05:00 | docs: add judge quick start and Build Week narrative                                           |
| [`3ecdc97a`](https://github.com/alex-tomilov/dry-validation-rust/commit/3ecdc97a19943bc1eca3f80dc87afc982742acc1) | 2026-07-20T17:48:30+05:00 | test: add clean-room submission verification                                                   |
| [`73db7a32`](https://github.com/alex-tomilov/dry-validation-rust/commit/73db7a32616c12ebe2da6f332ca878ba1615907a) | 2026-07-20T18:04:48+05:00 | docs: prepare Build Week video package                                                         |
| [`d21e0040`](https://github.com/alex-tomilov/dry-validation-rust/commit/d21e00403a6d5e4735bf81fb3b2a841a512919d2) | 2026-07-20T18:06:45+05:00 | ci: try to fix the CleanRoomVerificationTest                                                   |

Submission candidate at the time this file was generated:

- HEAD: `d21e00403a6d5e4735bf81fb3b2a841a512919d2`
- Generated: `2026-07-20T14:57:08Z`

## GPT-5.6, Codex, and human roles

| Participant  | Contribution                                                                                                                                                                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GPT-5.6      | Reviewed the feasibility prototype, identified correctness, compatibility, native-boundary, benchmark, packaging, CI, security, and documentation risks, and helped shape a staged roadmap. |
| Codex        | Inspected the repository, implemented accepted stages, refined tests, ran verification, diagnosed failures, and prepared Docker, CI, benchmark, and judge-facing material.                  |
| Human author | Chose the Ruby/Rust boundary, safe namespace, compatibility scope, fail-loud policy, claim limits, accepted roadmap stages, and final submission candidate.                                 |

Contextual shared conversation:

- https://chatgpt.com/share/6a5c38e4-c380-83ed-a4cb-ac221d42d905

The shared chat is supplementary context. Git history, CI runs, container digests, benchmark artifacts, and the Codex session ID provide implementation evidence.

## Evidence

Complete these values before submission:

- Primary Codex `/feedback` Session ID: `019f6b00-f639-7c82-a9f8-633407e9980f`
- Final submission tag: `build-week-2026`
- Public image: `ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026`
- Verified image digest: `<VERIFIED_GHCR_DIGEST>`
- Successful publication workflow: `<PUBLIC_WORKFLOW_URL>`
- Public video: `<PUBLIC_YOUTUBE_VIDEO_URL>`

Unknown values are submission blockers, not decorative placeholders.

## Human decisions and claim limits

The submission deliberately keeps these boundaries:

- `Dry::Validation::Rust` is the primary safe namespace.
- Exact upstream-like constants remain experimental and isolated.
- Unsupported behavior fails loudly.
- Compatibility claims require executable evidence against pinned upstream versions.
- Performance claims are workload- and environment-specific.
- Current execution still operates on Ruby objects under the GVL.
- The project is not presented as production-ready or as a full drop-in replacement.

## Final verification

From an anonymous environment:

```bash
docker logout ghcr.io 2>/dev/null || true
docker pull ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
docker run --rm ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
docker run --rm --network none \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026 test
```

For a source checkout:

```bash
bundle install
bundle exec rake compile
bundle exec rake test
script/verify
```
