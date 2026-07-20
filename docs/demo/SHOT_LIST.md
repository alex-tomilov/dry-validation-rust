# Build Week demo shot list

The edit has eight shots and a hard stop at 2:48. Use 1080p capture, a terminal
or editor font of at least 22 px, and no horizontally scrolling code. Capture
the terminal fallback stills during the successful preflight; do not fabricate
output after a failed take.

## Shot 1 — 0:00–0:15, maximum 15 seconds

- **Window:** Browser on the repository README, then the rendered Mermaid view.
- **Exact source:** `README.md:1-19`; `docs/ARCHITECTURE.md:3-19`.
- **Cursor/zoom:** Browser at 150%; keep the pointer outside the diagram.
- **Narration cue:** “Ruby validation keeps domain rules wonderfully
  expressive…”
- **Transition:** Six-frame dissolve from title to architecture.
- **Backup:** Static capture of the rendered architecture diagram, made from
  the same committed file.

## Shot 2 — 0:15–0:30, maximum 15 seconds

- **Window:** Clean terminal in the repository root.
- **Exact command:** The “Image identity” and “Offline demo” commands in
  `TERMINAL_COMMANDS.md`.
- **Cursor/zoom:** 24 px monospace; crop the prompt and keep the image reference
  plus first demo heading visible.
- **Narration cue:** “I built this verified local image…”
- **Transition:** Hard cut when the first demo heading appears.
- **Backup:** Successful preflight capture showing the local image reference
  and `native_extension_loaded=true`; never substitute a GHCR image.

## Shot 3 — 0:30–1:15, maximum 45 seconds

- **Window:** Terminal output from the offline Docker demo.
- **Exact source:** `examples/build_week_order_contract.rb:14-31` and
  `examples/build_week_order_contract.rb:61-139`; live command from
  `TERMINAL_COMMANDS.md`.
- **Cursor/zoom:** Do not scroll source. Pan the terminal crop between the three
  numbered sections; briefly box the named PASS lines.
- **Narration cue:** “This is one asserted order contract…”
- **Transition:** Match cut from `Demo complete: 10 checks passed` to the
  benchmark status heading.
- **Backup:** Static capture from the same successful preflight, including all
  three section headings and the final check count.

## Shot 4 — 1:15–1:35, maximum 20 seconds

- **Window:** Editor split view, no terminal benchmark execution.
- **Exact source:** `benchmark/results/build-week-2026/README.md:1-10` and
  `docs/BENCHMARKING.md:11-27`.
- **Cursor/zoom:** 22 px; emphasize “full evidence not generated yet” and the
  three workload names. Hide the editor file tree if it crowds the text.
- **Narration cue:** “The harness compares Rust with pinned upstream…”
- **Transition:** Short crossfade to the contextual ChatGPT view.
- **Backup:** Static capture of the same committed evidence-status file.

## Shot 5 — 1:35–1:50, maximum 15 seconds

- **Window:** Logged-out or privacy-cropped browser view of the authentic shared
  ChatGPT conversation.
- **Exact source:** The shared link in `docs/BUILD_WEEK_2026.md:51-68`.
- **Cursor/zoom:** 125–150%; hide browser profile, tabs, sidebar, account data,
  and unrelated conversation content.
- **Narration cue:** “During the event, I used GPT-5.6 through ChatGPT…”
- **Transition:** Hard cut to repository roadmap files.
- **Backup:** `docs/BUILD_WEEK_2026.md:51-68`; do not add a synthetic model
  badge or recreate the conversation.

## Shot 6 — 1:50–2:12, maximum 22 seconds

- **Window:** Editor on `docs/codex/stages/`, then a privacy-cropped Codex
  primary-thread view, then terminal Git evidence.
- **Exact source:** `docs/codex/README.md:42-58`,
  `docs/BUILD_WEEK_2026.md:70-101`, and the “Build Week boundary” command in
  `TERMINAL_COMMANDS.md`.
- **Cursor/zoom:** 22 px. Crop local paths, account identity, usage balances,
  session IDs, and unrelated prompts from the Codex view.
- **Narration cue:** “Codex implemented accepted stages…”
- **Transition:** Fast two-cut montage into engineering guardrails.
- **Backup:** Use the staged-roadmap tree plus the evidence-ledger table; never
  invent a Codex screenshot.

## Shot 7 — 2:12–2:38, maximum 26 seconds

- **Window:** Editor montage.
- **Exact source:** `AGENTS.md:14-25`,
  `.agents/skills/dvr-delivery-gate/SKILL.md:7-35`, `script/verify:1-18`,
  `docs/VERIFICATION.md:40-83`, and `docs/SUPPORT_MATRIX.md:14-28`.
- **Cursor/zoom:** Show one short region at a time at 22 px; no workflow YAML
  scrolling. Keep “fails loudly” and the verification command visible longest.
- **Narration cue:** “The repository turns those decisions into guardrails.”
- **Transition:** Fade to the end card on “scoped feasibility prototype.”
- **Backup:** Static `docs/VERIFICATION.md` view plus the support-matrix caveat.

## Shot 8 — 2:38–2:48, maximum 10 seconds

- **Window:** Manually prepared end card.
- **Exact text:** `github.com/alex-tomilov/dry-validation-rust`, “Developer
  Tools”, and the two local Docker commands from `TERMINAL_COMMANDS.md`.
- **Cursor/zoom:** No cursor; minimum 32 px text with high contrast.
- **Narration cue:** “This explores native validation…”
- **Transition:** Two-second silent tail after narration for a clean end.
- **Backup:** Repository README title with the Docker quick-start section.
