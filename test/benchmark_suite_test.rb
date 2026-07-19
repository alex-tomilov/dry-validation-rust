# frozen_string_literal: true

require_relative "test_helper"
require_relative "../benchmark/support/suite"
require "json"
require "open3"
require "tmpdir"

class BenchmarkSuiteTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, "script/benchmark-suite")

  def test_argument_parsing_exposes_quick_and_full_modes
    quick = DryValidationRustBenchmark::Configuration.parse(["--mode", "quick", "--output", "tmp/quick"])
    assert_equal 1, quick.runs
    assert_equal 50, quick.iterations
    assert_equal 10, quick.warmup_iterations
    refute quick.authoritative?

    full = DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", "tmp/full"])
    assert_equal 5, full.runs
    assert_equal 10_000, full.iterations
    assert_equal 1_000, full.warmup_iterations
    assert full.authoritative?

    error = assert_raises(DryValidationRustBenchmark::ConfigurationError) do
      DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", "tmp/full", "--runs", "4"])
    end
    assert_includes error.message, "at least 5 runs"

    error = assert_raises(DryValidationRustBenchmark::ConfigurationError) do
      DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", "tmp/full", "--engine", "rust"])
    end
    assert_includes error.message, "complete workload"

    error = assert_raises(DryValidationRustBenchmark::ConfigurationError) do
      DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", "tmp/full", "--iterations", "9999"])
    end
    assert_includes error.message, "at least 10000 iterations"
  end

  def test_summary_uses_medians_ranges_and_mechanical_ratios
    raw = [
      sample("dry-validation-rust", 1, 100.0, 70, 10_000),
      sample("dry-validation-rust", 2, 120.0, 74, 10_200),
      sample("dry-validation", 1, 20.0, 100, 20_000),
      sample("dry-validation", 2, 24.0, 104, 20_400)
    ]
    environment = {"commit_sha" => "abc123", "dirty_tree" => false, "authoritative" => true}

    summary = DryValidationRustBenchmark::Summarizer.build(raw, mode: "full", environment: environment)
    rust = summary.fetch("groups").fetch("shallow/mixed/dry-validation-rust")
    comparison = summary.fetch("comparisons").fetch(0)

    assert_equal 110.0, rust.dig("metrics", "throughput_per_second", "median")
    assert_equal 100.0, rust.dig("metrics", "throughput_per_second", "min")
    assert_equal 120.0, rust.dig("metrics", "throughput_per_second", "max")
    assert_in_delta 5.0, comparison.fetch("rust_to_upstream_throughput_ratio")
    assert_in_delta 72.0 / 102.0, comparison.fetch("rust_to_upstream_allocation_ratio")
    assert_in_delta 10_100.0 / 20_200.0, comparison.fetch("rust_to_upstream_peak_rss_ratio")
  end

  def test_summary_rejects_nonequivalent_engine_outcomes
    raw = [
      sample("dry-validation-rust", 1, 100.0, 70, 10_000),
      sample("dry-validation", 1, 20.0, 100, 20_000).merge("outcome_checksum" => "different")
    ]

    error = assert_raises(DryValidationRustBenchmark::EvidenceError) do
      DryValidationRustBenchmark::Summarizer.build(
        raw,
        mode: "quick",
        environment: {"commit_sha" => "abc123", "dirty_tree" => true, "authoritative" => false}
      )
    end
    assert_includes error.message, "engine outcomes differ"
  end

  def test_existing_output_requires_force
    Dir.mktmpdir("benchmark-suite-test") do |directory|
      output = File.join(directory, "existing")
      Dir.mkdir(output)
      File.write(File.join(output, "keep"), "evidence")
      configuration = DryValidationRustBenchmark::Configuration.parse(["--mode", "quick", "--output", output])

      error = assert_raises(DryValidationRustBenchmark::EvidenceError) do
        DryValidationRustBenchmark::Suite.new(configuration).prepare_output!
      end
      assert_includes error.message, "--force"
      assert_equal "evidence", File.read(File.join(output, "keep"))
    end
  end

  def test_full_mode_refuses_a_dirty_tree_before_writing_output
    Dir.mktmpdir("benchmark-suite-test") do |directory|
      output = File.join(directory, "full")
      configuration = DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", output])
      suite = DryValidationRustBenchmark::Suite.new(configuration)
      suite.define_singleton_method(:environment_metadata) do
        {"commit_sha" => "abc123", "dirty_tree" => true, "authoritative" => false}
      end

      error = assert_raises(DryValidationRustBenchmark::EvidenceError) { suite.call }
      assert_includes error.message, "clean tree"
      refute_path_exists output
    end
  end

  def test_full_mode_requires_rust_and_cargo_metadata
    Dir.mktmpdir("benchmark-suite-test") do |directory|
      output = File.join(directory, "full")
      configuration = DryValidationRustBenchmark::Configuration.parse(["--mode", "full", "--output", output])
      suite = DryValidationRustBenchmark::Suite.new(configuration)
      suite.define_singleton_method(:environment_metadata) do
        {"commit_sha" => "abc123", "dirty_tree" => false, "authoritative" => true, "rust" => nil, "cargo" => nil}
      end
      suite.define_singleton_method(:gnu_time_available?) { true }

      error = assert_raises(DryValidationRustBenchmark::EvidenceError) { suite.call }
      assert_includes error.message, "Rust and Cargo"
      refute_path_exists output
    end
  end

  def test_quick_mode_completes_and_writes_required_json_fields
    Dir.mktmpdir("benchmark-suite-test") do |directory|
      output = File.join(directory, "quick")
      stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--mode", "quick",
        "--output", output,
        "--engine", "rust",
        "--workload", "shallow",
        "--distribution", "mixed",
        "--iterations", "4",
        "--warmup", "1",
        chdir: PROJECT_ROOT
      )

      assert status.success?, stderr
      assert_empty stderr
      report = JSON.parse(stdout)
      assert_equal false, report.fetch("authoritative")

      environment = JSON.parse(File.read(File.join(output, "environment.json")))
      summary = JSON.parse(File.read(File.join(output, "summary.json")))
      raw_file = Dir[File.join(output, "raw/*.json")].fetch(0)
      raw = JSON.parse(File.read(raw_file))
      reproduce = File.read(File.join(output, "reproduce.sh"))

      %w[commit_sha dirty_tree os kernel architecture cpu_model cpu_count ruby rust cargo gem_versions benchmark_mode].each do |field|
        assert environment.key?(field), "missing environment field #{field}"
      end
      %w[schema_version mode authoritative groups comparisons].each do |field|
        assert summary.key?(field), "missing summary field #{field}"
      end
      %w[engine workload distribution run elapsed_seconds throughput_per_second allocated_objects peak_rss_kib exit_status processed_count outcome_checksum].each do |field|
        assert raw.key?(field), "missing raw field #{field}"
      end
      assert_equal 4, raw.fetch("processed_count")
      assert_equal 2, raw.fetch("success_count")
      assert_equal 2, raw.fetch("failure_count")
      refute_includes reproduce, PROJECT_ROOT
      refute_includes reproduce, ENV.fetch("HOME")
    end
  end

  def test_public_full_command_explicitly_replaces_the_placeholder
    documentation = File.read(File.join(PROJECT_ROOT, "docs/BENCHMARKING.md"))

    assert_includes documentation, "--output benchmark/results/build-week-2026 \\\n  --force"
  end

  private

  def sample(engine, run, throughput, allocations, rss)
    {
      "engine" => engine,
      "workload" => "shallow",
      "distribution" => "mixed",
      "run" => run,
      "iterations" => 10,
      "warmup_iterations" => 2,
      "elapsed_seconds" => 10.0 / throughput,
      "throughput_per_second" => throughput,
      "allocated_objects" => allocations,
      "peak_rss_kib" => rss,
      "processed_count" => 10,
      "success_count" => 5,
      "failure_count" => 5,
      "outcome_checksum" => "same"
    }
  end
end
