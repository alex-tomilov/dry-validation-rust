# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "tmpdir"

class DockerAssetsTest < Minitest::Test
  DISPATCHER = File.join(PROJECT_ROOT, "bin/dvr")

  def test_dockerfile_separates_build_and_non_root_runtime
    dockerfile = read_project_file("Dockerfile")
    runtime = dockerfile.split(/^FROM debian:bookworm-slim AS runtime$/, 2).last

    refute_nil runtime
    assert_includes dockerfile, "FROM rust:${RUST_VERSION}-slim-bookworm AS rust-toolchain"
    assert_includes dockerfile, "bundle exec rake compile"
    assert_includes dockerfile, "script/demo --json"
    assert_includes dockerfile, "benchmark/Gemfile.upstream.lock"
    assert_includes dockerfile, "BUNDLE_PATH=/opt/upstream-bundle"
    assert_includes runtime, "COPY --from=builder /usr/local/bin/ruby /usr/local/bin/ruby"
    assert_includes runtime, "COPY --from=builder /usr/local/lib/ruby/3.3.0 /usr/local/lib/ruby/3.3.0"
    assert_includes runtime, "COPY --from=builder /opt/upstream-bundle/ruby/3.3.0 /opt/upstream-gems"
    assert_includes runtime, "/ext/dry_validation_rust/native.so"
    assert_includes runtime, "USER 10001:10001"
    assert_includes runtime, 'ENTRYPOINT ["/opt/dry-validation-rust/bin/dvr"]'
    refute_match(/build-essential|\bclang\b|\bcargo\b|\brustc\b/i, runtime)
    refute_includes runtime, "/usr/local/include"
    refute_includes runtime, "/usr/local/bin/bundle"
    refute_includes runtime, "/usr/local/lib/ruby/gems"
    refute_includes dockerfile.downcase, "alpine"
  end

  def test_docker_context_excludes_local_build_and_credential_material
    dockerignore = read_project_file(".dockerignore")

    assert_includes dockerignore, "ext/dry_validation_rust/target"
    assert_includes dockerignore, "ext/dry_validation_rust/native.*"
    assert_includes dockerignore, ".env.*"
    assert_includes dockerignore, "*.pem"
    assert_includes dockerignore, "build-week-2026"
  end

  def test_docker_smoke_marks_uncommitted_images_as_dirty
    smoke = read_project_file("script/docker-smoke")

    assert_includes smoke, "status --porcelain --untracked-files=normal"
    assert_includes smoke, 'revision="${revision}-dirty"'
    assert_includes smoke, "--skip-build"
    assert_includes smoke, 'if [[ "$skip_build" == 1 ]]'
  end

  def test_dispatcher_help_and_unknown_command
    stdout, stderr, status = Open3.capture3(DISPATCHER, "help", chdir: Dir.tmpdir)
    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "demo [--json]"
    assert_includes stdout, "test"
    assert_includes stdout, "doctor"
    assert_includes stdout, "benchmark"

    unknown_stdout, unknown_stderr, unknown_status = Open3.capture3(
      DISPATCHER,
      "not-a-command",
      chdir: Dir.tmpdir
    )
    refute unknown_status.success?
    assert_empty unknown_stdout
    assert_includes unknown_stderr, "Unknown command: not-a-command"
  end

  def test_dispatcher_uses_precompiled_extension_for_runtime_smoke
    dispatcher = read_project_file("bin/dvr")
    stdout, stderr, status = Open3.capture3(DISPATCHER, "test", chdir: Dir.tmpdir)

    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "native_extension="
    assert_includes dispatcher, 'RbConfig::CONFIG.fetch("DLEXT")'
    refute_includes dispatcher, 'dry_validation_rust/native.so'
    report = JSON.parse(stdout.lines.drop(1).join)
    assert_equal true, report.fetch("success")
    assert_equal 10, report.fetch("checks_passed")
  end

  def test_doctor_limits_its_platform_support_claim
    dispatcher = read_project_file("bin/dvr")
    stdout, stderr, status = Open3.capture3(DISPATCHER, "doctor", chdir: Dir.tmpdir)

    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "platform=#{RUBY_PLATFORM}"
    assert_includes stdout, "native_extension_loaded=true"
    assert_includes stdout, "openai_api_key_required=false"
    assert_includes dispatcher, 'RUBY_PLATFORM == "x86_64-linux"'
    assert_includes dispatcher, "unverified image platform"
  end

  def test_benchmark_accepts_counts_and_rejects_invalid_values
    stdout, stderr, status = Open3.capture3(
      DISPATCHER,
      "benchmark",
      "--iterations", "7",
      "--warmup", "2",
      "--engine", "rust",
      chdir: Dir.tmpdir
    )

    assert status.success?, stderr
    assert_includes stderr, "Synthetic single-schema benchmark"
    report = JSON.parse(stdout)
    result = report.fetch("engines").fetch(0)
    assert_equal 7, result.fetch("iterations")
    assert_equal 2, result.fetch("warmup_iterations")

    _invalid_stdout, invalid_stderr, invalid_status = Open3.capture3(
      DISPATCHER,
      "benchmark",
      "--iterations", "0",
      chdir: Dir.tmpdir
    )
    refute invalid_status.success?
    assert_includes invalid_stderr, "--iterations must be a positive integer"
  end

  def test_upstream_benchmark_reference_is_pinned_and_isolated
    gemfile = read_project_file("benchmark/Gemfile.upstream")
    lockfile = read_project_file("benchmark/Gemfile.upstream.lock")
    benchmark = read_project_file("benchmark/schema_throughput.rb")

    assert_includes gemfile, 'gem "dry-validation", "1.11.1"'
    assert_includes gemfile, 'gem "dry-schema", "1.16.0"'
    assert_includes lockfile, "dry-validation (1.11.1)"
    assert_includes lockfile, "dry-schema (1.16.0)"
    assert_includes benchmark, 'gem "dry-validation", #{UPSTREAM_DRY_VALIDATION_VERSION.inspect}'
    assert_includes benchmark, 'Open3.capture3(env, RbConfig.ruby, "-e", source, chdir: Dir.tmpdir)'
  end

  def test_docker_documentation_distinguishes_prepared_and_verified_images
    documentation = read_project_file("docs/DOCKER.md")

    assert_includes documentation, "## Build locally"
    assert_includes documentation, "## Prepared GHCR publication"
    assert_includes documentation, "Preparing the workflow does not prove"
    assert_includes documentation, "--network none"
    assert_includes documentation, "--engine compare --iterations 100000 --warmup 10000"
    assert_includes documentation, "dry-validation` 1.11.1"
    assert_includes documentation, "median plus range or dispersion"
    assert_includes documentation, "appends `-dirty`"
    assert_includes documentation, "## Observed development benchmark snapshot"
    assert_includes documentation, "must be rerun"
    assert_includes documentation, "median of the five paired"
    assert_includes documentation, "They do not measure RSS or"
    assert_includes documentation, "Only `benchmark --engine"
    assert_includes documentation, "in a separate Ruby process"
    assert_includes documentation, "Linux x86-64 with glibc"
    assert_includes documentation, "ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026"
    assert_includes documentation, "currently **unavailable"
    assert_includes documentation, "<PUBLISHED_DIGEST>"
    assert_includes documentation, "Repository-owner publishing checklist"
    assert_includes documentation, "docker pull ghcr.io/alex-tomilov/dry-validation-rust:sha-<FULL_COMMIT_SHA>"
  end

  private

  def read_project_file(path)
    File.read(File.join(PROJECT_ROOT, path))
  end
end
