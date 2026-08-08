# frozen_string_literal: true

require 'memory_profiler'
require 'time'
require 'dry/validation/rust'

module AllocationProfiler
  ITERATIONS = 1000
  PROFILE_RUNS = 3
  SCENARIO = 'three-field valid params contract'

  module_function

  def measure
    {
      'allocations_per_call' => allocations_per_call,
      'iterations' => ITERATIONS,
      'profile_runs' => PROFILE_RUNS,
      'scenario' => SCENARIO,
      'ruby' => RUBY_DESCRIPTION,
      'platform' => RUBY_PLATFORM,
      'memory_profiler' => MemoryProfiler::VERSION,
      'recorded_at' => Time.now.utc.iso8601
    }
  end

  def allocations_per_call
    contract = Class.new(Dry::Validation::Rust::Contract) do
      params do
        required(:age).value(:integer, gt?: 0)
        required(:name).filled(:string)
        required(:active).value(:bool)
      end
    end.new
    payload = { 'age' => '42', 'name' => 'Jane', 'active' => 'true' }.freeze

    PROFILE_RUNS.times.map do
      report = MemoryProfiler.report { ITERATIONS.times { contract.call(payload) } }
      report.total_allocated.fdiv(ITERATIONS)
    end.min
  end
end
