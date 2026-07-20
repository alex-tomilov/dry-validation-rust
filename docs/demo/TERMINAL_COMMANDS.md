# Video terminal commands

These commands use the currently verified fallback: a Linux amd64 image built
locally from the submission checkout. The intended GHCR tag was not anonymously
accessible on July 20, 2026, so no public-image command appears in the recording
sequence.

Run everything from the repository root. Use a clean checkout with Docker and
Linux amd64 container support. The recorded runtime commands need no host Ruby,
Rust, Clang, Bundler, OpenAI key, or network access.

## Off-camera preflight

### 1. Confirm the candidate is clean

```bash
git status --short
```

Expected key output: no output. Any line means stop, review the change, and
prepare a clean submission commit before recording.

### 2. Build the precompiled image

```bash
docker build --pull --platform linux/amd64 \
  --build-arg "VCS_REF=$(git rev-parse HEAD)" \
  --tag dry-validation-rust:local .
```

Expected key output:

```text
{"demo":"dry-validation-rust deterministic order validation","success":true,"checks_passed":10,"checks_total":10,...}
... naming to docker.io/library/dry-validation-rust:local ...
```

Layer formatting varies by Docker version. The command must exit zero.

### 3. Preflight all runtime checks

```bash
script/docker-smoke --skip-build --tag dry-validation-rust:local \
  --platform linux/amd64
```

Expected final output:

```text
Docker smoke passed for dry-validation-rust:local
```

This check covers the text and JSON demos, `doctor`, packaged runtime test,
pinned benchmark smoke, unknown-command rejection, and network-disabled runs.

## Recorded terminal sequence

### 1. Clear the terminal

```bash
clear
```

Expected key output: an empty terminal viewport. This is presentation-only.

### 2. Image identity

```bash
docker image inspect \
  --format 'reference=dry-validation-rust:local id={{.Id}}' \
  dry-validation-rust:local
```

Expected key output:

```text
reference=dry-validation-rust:local id=sha256:<64 hexadecimal characters>
```

The image ID changes when the image contents change; do not paste a historical
ID into the video.

### 3. Offline deterministic demo

```bash
docker run --rm --network none --platform linux/amd64 \
  dry-validation-rust:local
```

Expected key output:

```text
[1/3] Valid nested input
PASS  customer age coerced to Integer
[2/3] Structural and Ruby rule errors
PASS  underage customer rejected by Ruby rule
[3/3] Failed coercion skips dependent rule
PASS  dependent customer age rule did not execute
Demo complete: 10 checks passed
```

### 4. Optional doctor cut

```bash
docker run --rm --network none --platform linux/amd64 \
  dry-validation-rust:local doctor
```

Expected key output includes:

```text
native_extension_loaded=true
runtime_uid=10001
support_status=verified Linux x86_64 judge image
openai_api_key_required=false
```

Do not show the local image revision if the checkout is dirty.

### 5. Committed benchmark evidence status

```bash
sed -n '1,8p' benchmark/results/build-week-2026/README.md
```

Expected key output:

```text
# Build Week 2026 benchmark evidence
Status: **full evidence not generated yet**.
...
benchmark package. No performance number is claimed from this placeholder.
```

This is intentionally a file-reading command, not a benchmark run. Do not show
the development-only snapshot from `docs/DOCKER.md` as submission evidence.

### 6. Build Week boundary

```bash
script/build-week-evidence | sed -n '1,9p'
```

Expected key output:

```text
Submission boundary: 2026-07-13T16:00:00Z
Active branch: feature/build-week-2026
Detected baseline:
  SHA: 6e986c164ddd7e9fab5854c81fa300c5df898476
...
Commits reachable from HEAD on or after the boundary:
```

The helper is read-only and prints repository evidence, not shell history or
the process environment.

## Recording safety

- Use a neutral shell prompt or crop it out; never show a username, hostname,
  home path, token, session ID, email address, or unrelated command history.
- Close password managers, chat notifications, cloud consoles, and private
  repository tabs before opening the terminal.
- Do not substitute a public registry reference until anonymous access and its
  immutable digest have been verified and documented.
- Stop if any expected line differs. Diagnose and rerun the preflight instead
  of editing terminal output.
