# Docker judge image

The Docker image is the shortest evaluation path for `dry-validation-rust`. It contains the compiled native extension and runs the deterministic demo without requiring Ruby, Rust, Clang, Bundler, or an OpenAI API key on the host.

## Published image

The container workflow publishes explicit Build Week and SHA tags to GitHub Container Registry. After the package is public, run:

```bash
docker pull \
  --platform linux/amd64 \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026

docker run --rm \
  --platform linux/amd64 \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
```

Use an immutable digest in final evidence when the workflow reports one:

```bash
docker run --rm \
  --platform linux/amd64 \
  ghcr.io/alex-tomilov/dry-validation-rust@sha256:<VERIFIED_DIGEST>
```

Do not replace `<VERIFIED_DIGEST>` until the registry has returned the real value.

## Local build

From the repository root:

```bash
docker build --pull --platform linux/amd64 \
  -t dry-validation-rust:local .
```

Run the default demo:

```bash
docker run --rm --network none --platform linux/amd64 \
  dry-validation-rust:local
```

Apple Silicon hosts can use Docker Desktop's amd64 emulation. Native arm64 support is not claimed by this image.

## Image commands

`bin/dvr` exposes a small command set:

```text
demo       run the deterministic demonstration (default)
test       run the packaged verification path
doctor     print packaged versions and extension-loading details
benchmark  run the explicitly requested quick benchmark
help       show commands
```

Examples:

```bash
docker run --rm dry-validation-rust:local demo
docker run --rm dry-validation-rust:local demo --json
docker run --rm dry-validation-rust:local doctor
docker run --rm dry-validation-rust:local test
```

The benchmark command is diagnostic and must not be presented as final comparative evidence.

## Verify the judge path

Run the repository smoke wrapper for a local image:

```bash
script/docker-smoke
```

Verify the published package anonymously:

```bash
docker logout ghcr.io 2>/dev/null || true

docker pull \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026

docker run --rm \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026

docker run --rm \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026 \
  demo --json

docker run --rm \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026 \
  doctor

docker run --rm --network none \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026 \
  test
```

Inspect the resolved digest:

```bash
docker inspect \
  --format='{{index .RepoDigests 0}}' \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
```

The GHCR workflow also pulls the published image by digest and smoke-tests that pulled artifact. That workflow result is the authoritative publication evidence; a Ruby test that parses workflow text would not prove the image works.

## Publishing from the Build Week branch

The branch does not need to be merged into `develop`. Tag the exact reviewed commit:

```bash
git switch feature/build-week-2026
git status --short
git tag -a build-week-2026 -m "OpenAI Build Week 2026 submission"
git push origin build-week-2026
```

The tag points directly to the branch commit. After publication:

1. make the GHCR package public;
2. pull it while logged out;
3. run the commands above;
4. record the workflow URL and digest in `docs/BUILD_WEEK_2026.md`;
5. avoid moving the tag after submission.

## Limits

- The published image targets `linux/amd64`.
- The runtime image is not evidence of native Windows or macOS support.
- Network independence applies after the image is pulled.
- The image demonstrates the documented compatibility subset, not full upstream parity.
