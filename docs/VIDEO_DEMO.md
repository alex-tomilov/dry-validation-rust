# Build Week video package

This file contains the recording script, screen plan, terminal sequence, asset checklist, and final review for a video shorter than three minutes.

Target length: **2:35–2:50**.

## Story and timing

| Time | Screen | Narration |
|---|---|---|
| 0:00–0:15 | Repository title and architecture diagram | Ruby validation DSLs are expressive, but repeated structural work can be expensive. This prototype keeps the dynamic DSL and business rules in Ruby while compiling a supported declarative schema plan for Rust. |
| 0:15–0:30 | Terminal with the public Docker command | Judges can run the precompiled Linux image with Docker only. The host needs no Ruby, Rust, Clang, Bundler, or OpenAI API key. |
| 0:30–1:12 | Run the deterministic demo | The first case normalizes string keys, coerces values, and validates nested items. The second combines structural failures with a Ruby business rule. The third proves that a failed coercion prevents its dependent rule from running. |
| 1:12–1:34 | Benchmark summary or methodology | Show only committed full-run evidence. Name the workload, upstream version, commit, and machine. State that the result is scenario-specific and that execution still uses Ruby objects under the GVL. |
| 1:34–2:12 | Build Week evidence and one Codex view | GPT-5.6 reviewed the feasibility prototype and helped shape a staged roadmap. Codex implemented and verified accepted work. The human author retained the architecture, scope, and claim boundaries. |
| 2:12–2:38 | CI, compatibility, and support documents | The project fails loudly for unsupported behavior, documents a narrow compatibility subset, and verifies the published container by digest. |
| 2:38–2:48 | Repository and Docker command | Close with the practical value: explore native structural validation without rewriting ordinary Ruby business rules. |

Do not say:

- full compatibility;
- production-ready;
- all validation runs in Rust;
- GVL-free or parallel validation;
- GPT-5.6 is integrated into the runtime;
- a universal speed or memory improvement.

## Recording commands

Pre-pull before recording so network time does not consume the video:

```bash
IMAGE=ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026

docker pull "$IMAGE"
docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE"
```

Clean terminal sequence:

```bash
clear
printf '%s\n' "$IMAGE"
docker run --rm --network none "$IMAGE"
```

Expected checkpoints:

```text
dry-validation-rust — deterministic demo
[1/3] Valid nested input
[2/3] Structural and Ruby rule errors
[3/3] Failed coercion skips dependent rule
Demo complete: 10 checks passed
```

Optional short diagnostic cut:

```bash
docker run --rm "$IMAGE" doctor
```

Show benchmark evidence from a committed file rather than executing the full suite during the recording:

```bash
sed -n '1,160p' benchmark/results/build-week-2026/summary.md
```

Use that command only when the file contains reviewed full-run evidence. Otherwise show `docs/BENCHMARKING.md` and omit performance numbers.

Concise Git evidence:

```bash
git log --since='2026-07-13T16:00:00Z' \
  --date=short \
  --pretty='format:%h  %ad  %s'
```

Do not display tokens, shell history, private paths, emails, or unreviewed screenshots.

## Screen guidance

- Use one editor window and one terminal.
- Keep text at least 18–22 px and avoid horizontal scrolling.
- Show only the relevant contract block, not entire files.
- Keep command output deterministic and pre-test every command on the submission tag.
- Use the architecture table from the README instead of a dense custom slide.
- Keep a static screenshot of the successful demo as a fallback if live execution fails.

## Assets

Prepare and privacy-review:

- repository title and value proposition;
- architecture table or diagram;
- deterministic demo;
- reviewed benchmark summary, if available;
- Build Week narrative and commit ledger;
- one contextual GPT-5.6 conversation view;
- one Codex session or `/feedback` view;
- successful container workflow and digest;
- final repository URL and Docker command.

Do not fabricate screenshots, model labels, session IDs, benchmark results, or image digests.

## Final checklist

- [ ] Public YouTube link works without authentication.
- [ ] Duration is under 3:00; target remains under 2:50.
- [ ] Voiceover or spoken audio is present.
- [ ] Terminal and source text remain readable on a phone.
- [ ] Notifications, tokens, emails, and private paths are hidden.
- [ ] Repository and GHCR package are public.
- [ ] Docker command was tested from an anonymous environment.
- [ ] Demonstration output matches the final submission tag.
- [ ] Any benchmark numbers match committed full evidence exactly.
- [ ] GPT-5.6, Codex, and human roles match available evidence.
- [ ] Captions are enabled when practical.
- [ ] Final playback was checked on desktop and mobile.
- [ ] Video URL was copied into the Devpost submission and Build Week document.
