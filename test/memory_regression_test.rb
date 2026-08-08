# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/allocation_profiler'
require 'json'

class MemoryRegressionTest < Minitest::Test
  BASELINE_PATH = File.join(PROJECT_ROOT, 'benchmark', 'baseline_allocations.json')
  MAXIMUM_REGRESSION = 1.05

  def test_allocations_per_call_stay_within_five_percent_of_main
    skip 'run with MEMORY_REGRESSION=1 to profile allocations' unless ENV['MEMORY_REGRESSION'] == '1'

    baseline = JSON.parse(File.read(ENV.fetch('ALLOCATION_BASELINE_PATH', BASELINE_PATH)))
    actual = AllocationProfiler.allocations_per_call
    maximum = baseline.fetch('allocations_per_call') * MAXIMUM_REGRESSION

    assert_operator actual, :<=, maximum,
                    "Allocations regressed: #{actual.round(2)} vs #{baseline.fetch('allocations_per_call')} baseline"
  end
end
