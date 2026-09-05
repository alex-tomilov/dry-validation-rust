# frozen_string_literal: true

# Run with: bundle exec ruby -Ilib benchmark/json_gvl.rb
# Allocation counts include Ruby result construction, not native heap allocations.
require 'json'
require 'dry/validation/rust'

contract = Class.new(Dry::Validation::Rust::Contract) do
  json do
    required(:items).array(:integer)
  end
end.new
iterations = Integer(ENV.fetch('N', '100'))
size = Integer(ENV.fetch('ITEMS', '10000'))
runs = Integer(ENV.fetch('RUNS', '3'))
raise ArgumentError, 'N, ITEMS and RUNS must be positive' unless [iterations, size, runs].all?(&:positive?)

payloads = {
  empty: [{ items: [] }, 0],
  integers: [{ items: Array.new(size, 1) }, size],
  discarded_strings: [{ items: [], ignored: Array.new(size) { |index| "value-#{index}" } }, 0]
}
payloads.each do |workload, (payload, count)|
  raw = JSON.generate(payload)
  { fused: -> { contract.call_json(raw) }, ruby_parse: -> { contract.call(JSON.parse(raw)) } }.each do |name, call|
    result = call.call
    raise 'unexpected validation output' unless result.success? && result.to_h == { items: Array.new(count, 1) }

    20.times { call.call }
    runs.times do |run|
      GC.start
      allocated = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      iterations.times { call.call }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      allocations = (GC.stat(:total_allocated_objects) - allocated).fdiv(iterations)
      puts JSON.generate(path: name, workload: workload, items: count, run: run + 1, calls_per_second: iterations / elapsed,
                         ruby_objects_per_call: allocations, ruby: RUBY_DESCRIPTION)
    end
  end
end
