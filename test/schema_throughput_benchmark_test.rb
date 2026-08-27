# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/schema_throughput'
require 'json'
require 'open3'

class SchemaThroughputBenchmarkTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, 'benchmark', 'schema_throughput.rb')

  def test_text_output_groups_metrics_in_a_scenario_section
    stdout, stderr, status = run_benchmark('text', engine: 'all')

    assert status.success?, stderr
    assert_includes stdout, '=' * 78
    assert_includes stdout, '1. Small Form'
    assert_includes stdout, 'Throughput — Benchmark.ips'
    assert_includes stdout, 'Warming up'
    assert_includes stdout, 'Calculating'
    assert_includes stdout, 'Comparison:'
    assert_includes stdout, 'Memory — MemoryProfiler'
    assert_includes stdout, 'allocated'
    assert_includes stdout, 'Peak RSS'
    assert_includes stdout, 'dry-validation-rust v'
  end

  def test_json_output_keeps_the_machine_readable_payload
    stdout, stderr, status = run_benchmark('json', memory_profile: true)

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal 'schema_throughput_matrix', payload.fetch('benchmark')
    result = payload.fetch('results').fetch(0)
    assert_equal 'small_form', result.fetch('scenario')
    assert_includes result, 'throughput_per_second'
    assert_includes result, 'ruby_allocated_objects_per_call'
    assert_includes result, 'peak_rss_kb'
    assert_equal 5, result.dig('memory_profile', 'iterations')
    assert_operator result.dig('memory_profile', 'total_allocated_objects'), :>, 0
    assert_operator result.dig('memory_profile', 'total_allocated_bytes'), :>, 0
  end

  def test_github_action_benchmark_output_uses_p95_latency_entries
    stdout, stderr, status = run_benchmark('github-action-benchmark')

    assert status.success?, stderr
    entry = JSON.parse(stdout).fetch(0)
    assert_equal 'dry-validation-rust small_form p95 latency', entry.fetch('name')
    assert_equal 'microseconds', entry.fetch('unit')
    assert_kind_of Numeric, entry.fetch('value')
    assert_includes entry.fetch('extra'), 'throughput_per_second:'
  end

  def test_fixed_run_loads_without_the_optional_memory_profiler_dependency
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      '--disable-gems',
      '-Ibenchmark/schema_throughput',
      '-e',
      "require 'fixed_run'",
      chdir: PROJECT_ROOT
    )

    assert_predicate status, :success?, stderr
  end

  def test_upstream_runner_does_not_preload_json_before_activating_the_bundle
    settings = SchemaThroughput::Settings.from_environment
    status = Struct.new(:success?).new(true)
    original_capture3 = Open3.method(:capture3)
    open3_singleton = Open3.singleton_class
    command = nil

    open3_singleton.send(:remove_method, :capture3)
    open3_singleton.define_method(:capture3, lambda { |_environment, *arguments|
      command = arguments
      ['[]', '', status]
    })

    begin
      assert_equal [], SchemaThroughput::CLI.upstream_results([], settings)
      refute_includes command, '-rjson'
    ensure
      open3_singleton.send(:remove_method, :capture3)
      open3_singleton.define_method(:capture3, original_capture3)
    end
  end

  private

  def run_benchmark(format, engine: 'rust', memory_profile: false)
    environment = {
      'ENGINE' => engine,
      'FORMAT' => format,
      'SCENARIO' => 'small_form',
      'N' => '5',
      'WARMUP' => '0',
      'LATENCY_SAMPLES' => '1',
      'IPS_TIME' => '0.01',
      'IPS_WARMUP' => '0.01',
      'MEMORY_PROFILE' => memory_profile.to_s,
      'MEMORY_PROFILE_N' => '5'
    }
    Open3.capture3(environment, RbConfig.ruby, '-Ilib', SCRIPT, chdir: PROJECT_ROOT)
  end
end
