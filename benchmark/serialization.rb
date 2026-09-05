# frozen_string_literal: true

# Compare native result serialization with Ruby JSON generation.
# Run: ruby -Ilib benchmark/serialization.rb
# N controls iterations per sample; five samples report median throughput.
require 'json'
require 'dry/validation/rust'

iterations = Integer(ENV.fetch('N', '10000'))
raise ArgumentError, 'N must be positive' unless iterations.positive?

contract = Class.new(Dry::Validation::Rust::Contract) do
  json do
    required(:items).array(:hash) do
      required(:id).value(:integer)
      required(:name).value(:string)
    end
  end
end.new

[1, 100].each do |size|
  result = contract.call(items: Array.new(size) { |i| { id: i, name: "item #{i}" } })
  raise 'JSON output mismatch' unless result.to_json == JSON.generate(result.to_h)

  { native: -> { result.to_json }, ruby: -> { JSON.generate(result.to_h) } }.each do |engine, operation|
    1000.times { operation.call }
    samples = Array.new(5) do
      GC.start
      allocated = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      iterations.times { operation.call }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      { throughput: iterations / elapsed, allocations: (GC.stat(:total_allocated_objects) - allocated).fdiv(iterations) }
    end
    puts JSON.generate(size: size, engine: engine,
                       median_calls_per_second: samples.map { |sample| sample[:throughput] }.sort[2],
                       median_allocations_per_call: samples.map { |sample| sample[:allocations] }.sort[2])
  end
end
