# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/schema_throughput/process_memory'

class ProcessMemoryTest < Minitest::Test
  def test_snapshot_reports_current_process_rss_when_available
    snapshot = SchemaThroughput::ProcessMemory.snapshot

    assert_kind_of Hash, snapshot
    assert_operator snapshot.fetch('rss_kb'), :>, 0 if snapshot.key?('rss_kb')
  end

  def test_measurement_keeps_before_after_and_peak_growth
    before = { 'rss_kb' => 100, 'peak_rss_kb' => 120, 'pss_kb' => 80, 'uss_kb' => 70 }
    after = { 'rss_kb' => 130, 'peak_rss_kb' => 150, 'pss_kb' => 95, 'uss_kb' => 85 }

    result = SchemaThroughput::ProcessMemory.measurement(before: before, after: after)

    assert_equal 150, result.fetch('peak_rss_kb')
    assert_equal 30, result.fetch('peak_rss_growth_kb')
    assert_equal 30, result.dig('delta_kb', 'rss_kb')
    assert_equal 15, result.dig('delta_kb', 'pss_kb')
    assert_equal 15, result.dig('delta_kb', 'uss_kb')
  end
end
