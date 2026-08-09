# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/allocation_profiler'

class AllocationProfilerTest < Minitest::Test
  def test_measure_records_the_regression_gate_scenario_and_runtime_metadata
    measurement = AllocationProfiler.measure

    assert_operator measurement.fetch('allocations_per_call'), :>, 0
    assert_equal AllocationProfiler::ITERATIONS, measurement.fetch('iterations')
    assert_equal AllocationProfiler::PROFILE_RUNS, measurement.fetch('profile_runs')
    assert_equal AllocationProfiler::SCENARIO, measurement.fetch('scenario')
    assert_equal RUBY_DESCRIPTION, measurement.fetch('ruby')
    assert_equal RUBY_PLATFORM, measurement.fetch('platform')
    assert_equal MemoryProfiler::VERSION, measurement.fetch('memory_profiler')
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, measurement.fetch('recorded_at'))
  end
end
