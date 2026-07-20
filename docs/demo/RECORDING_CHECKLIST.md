# Build Week recording checklist

Requirements were checked on July 20, 2026 against the
[official rules](https://openai.devpost.com/rules) and
[official FAQ](https://openai.devpost.com/details/faqs). The rules remain the
authority if this checklist conflicts with them.

## Eligibility and format

- [ ] Final edit is **under 3:00**; target 2:35–2:50 and verify the exported
  file duration, not only the editor timeline.
- [ ] Video is uploaded to YouTube and is publicly visible in a logged-out
  browser.
- [ ] Video clearly demonstrates the working project.
- [ ] Audio/voiceover is present and intelligible; background music alone does
  not qualify.
- [ ] Voiceover explains what was built, how Codex was used, and how GPT-5.6
  was used.
- [ ] Submission is in English, or an English translation is supplied.
- [ ] Music, logos, screenshots, and other third-party material are owned,
  licensed, or used with permission; remove unlicensed copyrighted music.

## Readability and recording environment

- [ ] Capture/export is 1080p or higher with a readable 16:9 layout.
- [ ] Terminal/editor font is at least 22 px; end-card text is at least 32 px.
- [ ] No shot requires horizontal source-code scrolling.
- [ ] Desktop notifications, browser profiles, bookmarks, unrelated tabs,
  password managers, and chat sidebars are hidden.
- [ ] No tokens, API keys, credentials, email addresses, usernames, hostnames,
  home paths, shell history, usage balances, or private session identifiers are
  visible or audible.
- [ ] Cursor rests outside important text and does not flicker between lines.

## Candidate and evidence preflight

- [ ] Recording uses a reviewed, clean submission commit; `git status --short`
  prints nothing.
- [ ] Every command in `TERMINAL_COMMANDS.md` was rerun successfully against
  that commit.
- [ ] Local Docker fallback was built from that commit and the runtime demo was
  rerun with `--network none`.
- [ ] Repository URL is publicly accessible, or the private repository is
  shared with the official judging addresses specified by Devpost.
- [ ] If a public image replaces the local fallback, a logged-out anonymous
  pull, immutable digest, and offline smoke have passed and the docs agree.
- [ ] Benchmark wording matches the committed evidence package exactly. With
  the current placeholder, the video states that no headline number is ready.
- [ ] GVL limitation and workload-specific benchmark scope remain explicit.
- [ ] GPT-5.6/Codex claims match `docs/BUILD_WEEK_2026.md` and the evidence
  ledger; they describe development contributions, not runtime integration.
- [ ] Human ownership of architecture, feature scope, evidence boundaries, and
  acceptance decisions is explicit.
- [ ] The project is called a feasibility prototype, not production-ready or a
  full compatibility replacement.

## Manual evidence and assets

- [ ] Narration was read aloud with a timer and the real result replaced the
  placeholder in `VIDEO_SCRIPT.md`.
- [ ] Shared-chat capture is authentic, privacy-reviewed, and does not add a
  model badge that is absent from the source.
- [ ] Codex capture comes from a real relevant thread and is cropped to remove
  account details, local paths, balances, tokens, and session identifiers.
- [ ] Primary `/feedback` Session ID was obtained from the representative core
  build thread and placed in the submission form and Build Week narrative.
- [ ] Backup stills came from the successful preflight, not recreated output.
- [ ] Captions/subtitles are added and checked when practical.

## Final submission pass

- [ ] Watch the exported video once with sound on desktop.
- [ ] Watch the public YouTube video once on mobile with captions enabled.
- [ ] Confirm YouTube processing preserved readable terminal text and audio.
- [ ] Insert the public YouTube URL into `docs/BUILD_WEEK_2026.md` and the
  Devpost submission form.
- [ ] Open the final repository and video links in a logged-out browser.
- [ ] Confirm the submitted track is Developer Tools and all required fields,
  including the `/feedback` Session ID, are complete.
- [ ] Submit before the deadline and confirm the saved Devpost entry.
