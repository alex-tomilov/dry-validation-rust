# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/allocation_profiler'
require 'json'

class MemoryRegressionTest < Minitest::Test
  BASELINE_PATH = File.join(PROJECT_ROOT, 'benchmark', 'baseline_allocations.json')
  MAXIMUM_REGRESSION = 1.05
  JSON_ALLOCATION_ITERATIONS = 100

  def test_json_streaming_allocates_fewer_hashes_and_strings
    contract = json_contract
    raw = '{"email":"test@example.com","age":25}'
    assert_json_results_match(contract, raw)

    streaming = profile_json_allocations { contract.call_json(raw) }
    standard = profile_json_allocations { contract.call(JSON.parse(raw)) }
    streaming_objects = hashes_and_strings(streaming).fdiv(JSON_ALLOCATION_ITERATIONS)
    standard_objects = hashes_and_strings(standard).fdiv(JSON_ALLOCATION_ITERATIONS)

    # Final Ruby results still allocate: this budget excludes other object types
    # and native heap allocations, and does not claim zero-copy result construction.
    assert_operator streaming_objects, :<=, 10,
                    "Streaming allocated #{streaming_objects} Hash/String objects per call"
    assert_operator streaming_objects, :<, standard_objects,
                    "Streaming: #{streaming_objects}, JSON.parse + call: #{standard_objects} Hash/String objects per call"
  end

  def test_json_streaming_skips_ruby_allocations_for_undeclared_values
    contract = json_contract
    raw = JSON.generate(email: 'test@example.com', age: 25,
                        ignored: Array.new(100) { |index| { nested: ["value-#{index}"] } })
    assert_json_results_match(contract, raw)

    streaming = profile_json_allocations { contract.call_json(raw) }
    standard = profile_json_allocations { contract.call(JSON.parse(raw)) }
    declared_only = profile_json_allocations { contract.call_json('{"email":"test@example.com","age":25}') }

    assert_operator streaming.total_allocated, :<, standard.total_allocated,
                    "Streaming: #{streaming.total_allocated}, JSON.parse + call: #{standard.total_allocated} Ruby objects"
    assert_operator streaming.total_allocated, :<=, declared_only.total_allocated,
                    'Undeclared nested values must not add Ruby object allocations'
  end

  def test_allocations_per_call_stay_within_five_percent_of_main
    skip 'run with MEMORY_REGRESSION=1 to profile allocations' unless ENV['MEMORY_REGRESSION'] == '1'

    baseline = JSON.parse(File.read(ENV.fetch('ALLOCATION_BASELINE_PATH', BASELINE_PATH)))
    actual = AllocationProfiler.allocations_per_call
    maximum = baseline.fetch('allocations_per_call') * MAXIMUM_REGRESSION

    assert_operator actual, :<=, maximum,
                    "Allocations regressed: #{actual.round(2)} vs #{baseline.fetch('allocations_per_call')} baseline"
  end

  private

  def json_contract
    build_contract do
      json do
        required(:email).filled(:string)
        required(:age).filled(:integer)
      end
    end.new
  end

  def assert_json_results_match(contract, raw)
    streaming = contract.call_json(raw)
    standard = contract.call(JSON.parse(raw))

    assert streaming.success?
    assert standard.success?
    assert_equal({ email: 'test@example.com', age: 25 }, streaming.to_h)
    assert_equal standard.to_h, streaming.to_h
    assert_equal standard.errors.to_h, streaming.errors.to_h
  end

  def profile_json_allocations(&call)
    # Compile the schema and warm lazy caches outside the measured region.
    # MemoryProfiler counts allocated objects even when GC later collects them.
    20.times(&call)
    MemoryProfiler.report { JSON_ALLOCATION_ITERATIONS.times(&call) }
  end

  def hashes_and_strings(report)
    report.allocated_objects_by_class.sum do |entry|
      %w[Hash String].include?(entry.fetch(:data)) ? entry.fetch(:count) : 0
    end
  end
end
