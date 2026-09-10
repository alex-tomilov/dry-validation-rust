# frozen_string_literal: true

# Run with: N=2000 RUNS=5 bundle exec ruby -Ilib benchmark/rule_evaluation.rb
# Allocation counts include Ruby result construction, not native heap allocations.
require 'json'
require 'dry/validation/rust'

module RuleEvaluationBenchmark
  ITERATIONS = Integer(ENV.fetch('N', '2000'))
  RUNS = Integer(ENV.fetch('RUNS', '5'))

  module_function

  def run
    raise ArgumentError, 'N and RUNS must be positive' unless [ITERATIONS, RUNS].all?(&:positive?)

    workloads.each do |name, workload|
      verify!(workload)
      20.times { workload.fetch(:call).call }

      RUNS.times do |run_number|
        puts JSON.generate(measure(name, workload.fetch(:call), run_number + 1))
      end
    end
  end

  def workloads
    @workloads ||= {
      simple_pass: workload(simple_rule_contract, simple_payload, success: true),
      simple_fail: workload(simple_rule_contract, failing_simple_payload, success: false),
      each_pass: workload(each_rule_contract, each_payload('1'), success: true),
      each_fail: workload(each_rule_contract, each_payload('0'), success: false)
    }.freeze
  end

  def workload(contract, payload, success:)
    { call: -> { contract.call(payload) }, success: success }.freeze
  end

  def simple_rule_contract
    @simple_rule_contract ||= Class.new(Dry::Validation::Rust::Contract) do
      params { 10.times { |index| required(:"field_#{index}").value(:integer) } }
      10.times { |index| rule(:"field_#{index}") { key.failure('must be positive') if value <= 0 } }
    end.new
  end

  def each_rule_contract
    @each_rule_contract ||= Class.new(Dry::Validation::Rust::Contract) do
      params { required(:numbers).array(:integer) }
      rule(:numbers).each { key.failure('must be positive') if value <= 0 }
    end.new
  end

  def simple_payload
    @simple_payload ||= (0...10).to_h { |index| ["field_#{index}", (index + 1).to_s] }.freeze
  end

  def failing_simple_payload
    @failing_simple_payload ||= (0...10).to_h { |index| ["field_#{index}", '0'] }.freeze
  end

  def each_payload(value)
    { numbers: Array.new(100, value).freeze }.freeze
  end

  def verify!(workload)
    result = workload.fetch(:call).call
    raise 'unexpected validation outcome' unless result.success? == workload.fetch(:success)
  end

  def measure(workload, call, run_number)
    GC.start
    allocated_before = GC.stat(:total_allocated_objects)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ITERATIONS.times { call.call }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    {
      benchmark: 'rule_evaluation',
      workload: workload,
      run: run_number,
      iterations: ITERATIONS,
      calls_per_second: ITERATIONS.fdiv(elapsed),
      ruby_objects_per_call: (GC.stat(:total_allocated_objects) - allocated_before).fdiv(ITERATIONS),
      ruby: RUBY_DESCRIPTION,
      platform: RUBY_PLATFORM
    }
  end
end

RuleEvaluationBenchmark.run if $PROGRAM_NAME == __FILE__
