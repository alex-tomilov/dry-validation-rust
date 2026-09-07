# frozen_string_literal: true

# Compare native result serialization with Ruby JSON generation.
#
# The default matrix is intended for local diagnosis. It calibrates each
# workload/engine sample to SAMPLE_SECONDS (0.5 by default), so fast scalar
# cases are not decided by millisecond-scale timings. FAST=1 is a smoke mode,
# not a source of performance claims.
#
# Run: bundle exec ruby -Ilib benchmark/serialization.rb
# Useful controls: FAST=1, SAMPLE_SECONDS=1, SAMPLES=7, N=100000,
# SIZES=10,100, WORKLOADS=array_int,array_hash
require 'json'
require 'dry/validation/rust'

DEFAULT_SIZES = [1, 10, 100, 1000].freeze
WORKLOADS = %w[small_hash wide_hash array_int array_hash escaped_string non_ascii_string].freeze

def positive_integer(environment, name, default)
  value = Integer(environment.fetch(name, default.to_s))
  raise ArgumentError, "#{name} must be positive" unless value.positive?

  value
end

def positive_float(environment, name, default)
  value = Float(environment.fetch(name, default.to_s))
  raise ArgumentError, "#{name} must be positive" unless value.positive?

  value
end

def selected_values(environment, name, default, permitted)
  values = environment.fetch(name, default.join(',')).split(',').reject(&:empty?)
  unknown = values - permitted
  raise ArgumentError, "unknown #{name}: #{unknown.join(', ')}" unless unknown.empty?

  values
end

def median(values)
  sorted = values.sort
  middle = sorted.length / 2
  return sorted[middle] if sorted.length.odd?

  (sorted[middle - 1] + sorted[middle]).fdiv(2)
end

def relative_mad_percent(values)
  midpoint = median(values)
  return 0.0 if midpoint.zero?

  median(values.map { |value| (value - midpoint).abs }).fdiv(midpoint) * 100
end

def contract(&definition)
  Class.new(Dry::Validation::Rust::Contract) do
    json(&definition)
  end.new
end

def small_hash_workload
  instance = contract do
    required(:id).value(:integer)
    required(:name).value(:string)
  end
  [1, instance.call(id: 42, name: 'ordinary ASCII')]
end

def wide_hash_workload
  keys = (1..20).map { |index| :"field_#{index}" }
  instance = contract do
    keys.each { |key| required(key).value(:string) }
  end
  [keys.length, instance.call(keys.to_h { |key| [key, "value for #{key}"] })]
end

def array_int_workload(size)
  instance = contract { required(:items).array(:integer) }
  [size, instance.call(items: Array.new(size) { |index| index - (size / 2) })]
end

def array_hash_workload(size)
  instance = contract do
    required(:items).array(:hash) do
      required(:id).value(:integer)
      required(:name).value(:string)
    end
  end
  [size, instance.call(items: Array.new(size) { |index| { id: index, name: "item #{index}" } })]
end

def escaped_string_workload(size)
  value = "quote: \" slash: \\ newline:\n tab:\t control:\u0001"
  instance = contract { required(:items).array(:string) }
  [size, instance.call(items: Array.new(size, value))]
end

def non_ascii_string_workload(size)
  values = ['Алексей', 'Казахстан', '日本語', 'emoji 😀']
  instance = contract { required(:items).array(:string) }
  [size, instance.call(items: Array.new(size) { |index| values[index % values.length] })]
end

def workload_cases(workloads, sizes)
  workloads.flat_map do |workload|
    case workload
    when 'small_hash' then [[workload, *small_hash_workload]]
    when 'wide_hash' then [[workload, *wide_hash_workload]]
    else sizes.map { |size| [workload, *send("#{workload}_workload", size)] }
    end
  end
end

def measure(operation, iterations)
  GC.start
  allocated = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { operation.call }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  {
    throughput: iterations.fdiv(elapsed),
    allocations: (GC.stat(:total_allocated_objects) - allocated).fdiv(iterations)
  }
end

def calibrated_iterations(operation, target_seconds, override)
  return override if override

  calibration = measure(operation, 1000)
  [(calibration[:throughput] * target_seconds).ceil, 1].max
end

def benchmark_engine(operation, iterations, samples, target_seconds)
  operation.call # Exclude first-call setup from allocation measurement.
  1000.times { operation.call }
  iterations ||= calibrated_iterations(operation, target_seconds, nil)
  [iterations, Array.new(samples) { measure(operation, iterations) }]
end

fast = ENV.fetch('FAST', '0') == '1'
sample_seconds = positive_float(ENV, 'SAMPLE_SECONDS', fast ? 0.05 : 0.5)
sample_count = positive_integer(ENV, 'SAMPLES', fast ? 2 : 5)
iteration_override = ENV.key?('N') ? positive_integer(ENV, 'N', 1) : nil
sizes = selected_values(ENV, 'SIZES', DEFAULT_SIZES, DEFAULT_SIZES.map(&:to_s)).map(&:to_i)
workloads = selected_values(ENV, 'WORKLOADS', WORKLOADS, WORKLOADS)

workload_cases(workloads, sizes).each_with_index do |(workload, size, result), workload_index|
  expected = JSON.generate(result.to_h)
  raise "#{workload}/#{size}: JSON output mismatch" unless result.to_json == expected

  operations = { native: -> { result.to_json }, ruby: -> { JSON.generate(result.to_h) } }
  measurements = {}
  iterations = {}
  engines = workload_index.odd? ? operations.keys.reverse : operations.keys
  engines.each do |engine|
    iterations[engine], measurements[engine] = benchmark_engine(
      operations.fetch(engine), iteration_override, sample_count, sample_seconds
    )
  end

  operations.each_key do |engine|
    samples = measurements.fetch(engine)
    throughputs = samples.map { |sample| sample[:throughput] }
    allocations = samples.map { |sample| sample[:allocations] }
    puts JSON.generate(
      workload: workload,
      size: size,
      engine: engine,
      iterations_per_sample: iterations.fetch(engine),
      samples: sample_count,
      median_calls_per_second: median(throughputs),
      min_calls_per_second: throughputs.min,
      max_calls_per_second: throughputs.max,
      relative_mad_percent: relative_mad_percent(throughputs),
      median_ruby_allocations_per_call: median(allocations),
      median_allocations_per_call: median(allocations)
    )
  end
end
