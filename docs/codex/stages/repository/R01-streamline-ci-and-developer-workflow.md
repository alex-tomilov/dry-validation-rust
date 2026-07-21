# Codex stage R01: streamline CI and developer workflow

**Priority:** P1  
**Dependencies:** None

## Assignment

Keep one canonical local verification path and make CI call it or its focused
subtasks. Add tooling only when it catches real defects without creating a new
metadata-maintenance system.

## Work

- Maintain supported Ruby/platform and Rust MSRV/stable checks, package audit,
  security audit, compatibility preflight, and bounded fuzz scheduling.
- Add `bin/setup` or a devcontainer only if it is exercised and materially
  improves onboarding.
- Apply Rustfmt/Clippy and optional Ruby lint with focused configuration.
- Validate workflow syntax and least privilege; keep publishing credentials out
  of pull-request workflows.
- Remove duplicate commands and obsolete placeholder stage references.

## Files

`script/verify`, Rake tasks, dependency files, workflows, and concise developer
instructions.

## Scope control

Do not replace prose/meta tests with an equally brittle file-existence shell
script. Do not add doc-comment lint, badge checks, or exact workflow-text tests.
Remote branch protection and repository settings require explicit authorization.

## Acceptance criteria

- Local canonical verification and CI responsibilities are consistent.
- Each added job has a failure it meaningfully detects.
- CI permissions are least-privilege and no publish secret is exposed.
- Developer setup remains optional, reproducible, and documented once.
