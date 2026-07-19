#!/usr/bin/env bash
set -euo pipefail

project_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
cd "$project_root"

if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  printf '%s\n' 'Refusing to generate committed benchmark evidence from a dirty tree.' >&2
  exit 1
fi

/usr/bin/time --version >/dev/null
command -v rustc >/dev/null
command -v cargo >/dev/null
bundle check

env \
  -u BUNDLE_BIN_PATH \
  -u BUNDLE_GEMFILE \
  -u RUBYLIB \
  -u RUBYOPT \
  ruby -e '
    gem "dry-validation", "1.11.1"
    gem "dry-schema", "1.16.0"
    require "dry/validation"
    abort "unexpected dry-validation version" unless Gem.loaded_specs.fetch("dry-validation").version.to_s == "1.11.1"
    abort "unexpected dry-schema version" unless Gem.loaded_specs.fetch("dry-schema").version.to_s == "1.16.0"
  '

bundle exec rake compile
exec script/benchmark-suite \
  --mode full \
  --output benchmark/results/build-week-2026 \
  --force
