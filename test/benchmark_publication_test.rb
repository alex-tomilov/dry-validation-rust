# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/schema_throughput/publication'

class BenchmarkPublicationTest < Minitest::Test
  def test_runner_announces_expected_duration_and_measurement_progress
    config = SchemaThroughput::Publication::Config.from_environment({}, project_root: PROJECT_ROOT)
    runner = SchemaThroughput::Publication::Runner.new(config: config, project_root: PROJECT_ROOT)
    state = {
      'environment' => { 'git_short_sha' => 'abc123' },
      'measurements' => []
    }
    scenarios = [{ 'name' => 'one' }, { 'name' => 'two' }]

    _, stderr = capture_io do
      runner.send(:announce, state, '/tmp/publication.checkpoint.json', scenarios)
      state['measurements'] << {}
      runner.send(:announce_measurement_progress, state, scenarios)
    end

    assert_includes stderr, 'Plan: 20 isolated measurements (5 runs × 2 scenarios × 2 engines); about 1m 40s of measured work remaining'
    assert_includes stderr, 'Measurement progress: 0/20 complete'
    assert_includes stderr, 'Measurement progress: 1/20 complete'
  end

  def test_statistics_report_median_range_and_variability_without_dropping_values
    summary = SchemaThroughput::Publication::Statistics.summary([100, 90, 110, 100, 100])

    assert_equal [100.0, 90.0, 110.0, 100.0, 100.0], summary.fetch('values')
    assert_equal 100.0, summary.fetch('median')
    assert_equal 90.0, summary.fetch('min')
    assert_equal 110.0, summary.fetch('max')
    assert_equal 0.0, summary.fetch('mad')
    assert_in_delta 20.0, summary.fetch('spread_pct'), 0.001
  end

  def test_markdown_names_commit_and_marks_memory_metrics_precisely
    metric = {
      'values' => [2.0, 2.1, 2.2],
      'median' => 2.1,
      'min' => 2.0,
      'max' => 2.2,
      'mad' => 0.1,
      'mad_pct' => 4.76,
      'spread_pct' => 9.52
    }
    rate = metric.merge('values' => [1000.0, 1050.0, 1100.0], 'median' => 1050.0, 'min' => 1000.0, 'max' => 1100.0)
    state = {
      'environment' => {
        'git_sha' => 'abc123', 'git_dirty' => false, 'recorded_at' => '2026-08-22T00:00:00Z',
        'ruby' => 'ruby 3.3.7', 'cpu_model' => 'Test CPU', 'host_os' => 'linux',
        'ruby_platform' => 'x86_64-linux', 'rustc' => 'rustc 1.90.0'
      },
      'protocol' => { 'runs' => 5, 'target_seconds' => 5 },
      'summary' => {
        'small_form' => {
          'rust_throughput_per_second' => rate,
          'upstream_throughput_per_second' => rate.merge('median' => 500.0, 'min' => 490.0, 'max' => 510.0),
          'throughput_speedup' => metric,
          'ruby_allocation_reduction_pct' => metric.merge('median' => -10.0, 'min' => -12.0, 'max' => -8.0),
          'peak_rss_reduction_pct' => metric.merge('median' => 15.0, 'min' => 14.0, 'max' => 16.0)
        }
      }
    }

    markdown = SchemaThroughput::Publication::Markdown.render(state)

    assert_includes markdown, 'Commit: `abc123`'
    assert_includes markdown, '2.10× (2.00–2.20)'
    assert_includes markdown, '15.0% (14.0–16.0)'
    assert_includes markdown, '-10.0% (-12.0–-8.0)'
    assert_includes markdown, 'Ruby allocation reduction refers to Ruby object allocations'
    assert_includes markdown, 'Outliers: never removed automatically'
  end
end
