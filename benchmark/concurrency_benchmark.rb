# frozen_string_literal: true

require 'benchmark'
require 'json'
require 'open3'
require 'rbconfig'

# Measures concurrent calls to equivalent Rust-backed and upstream contracts.
#
# Each thread makes the same number of calls, so the reported scale factor is
# normalized by the total number of calls: a value near the thread count means
# the work parallelized, while a value near 1.0 means it remained serialized.
# rubocop:disable Metrics/ModuleLength
module ConcurrencyBenchmark
  THREAD_COUNTS = [1, 2, 4].freeze
  ENGINES = %w[rust upstream].freeze
  ENGINE_ENV = 'CONCURRENCY_BENCHMARK_ENGINE'
  DEFAULT_ITERATIONS = 10_000

  module_function

  def benchmark_threads(contract, input, thread_count, iterations:)
    threads = thread_count.times.map do
      Thread.new do
        iterations.times do
          result = contract.call(input)
          raise 'benchmark validation unexpectedly failed' unless result.success?
        end
      end
    end

    threads.each(&:join)
  end

  def contract_for(engine)
    contract_class = case engine
                     when 'rust'
                       require 'dry/validation/rust'
                       Dry::Validation::Rust::Contract
                     when 'upstream'
                       gem 'dry-validation', ENV.fetch('UPSTREAM_VERSION', '1.11.1')
                       require 'dry/validation'
                       Dry::Validation::Contract
                     else
                       raise ArgumentError, "unknown benchmark engine: #{engine.inspect}"
                     end

    Class.new(contract_class) do
      params do
        required(:age).value(:integer, gt?: 17)
        required(:name).filled(:string)
        required(:email).filled(:string)
        required(:active).value(:bool)
        required(:score).value(:float, gteq?: 0.0)
        required(:role).filled(:string)
        required(:country).filled(:string)
        required(:visits).value(:integer, gteq?: 0)
        required(:ratio).value(:float, gteq?: 0.0)
        required(:enabled).value(:bool)
      end
    end.new
  end

  def input
    {
      'age' => '42', 'name' => 'Ada Lovelace', 'email' => 'ada@example.test',
      'active' => 'true', 'score' => '98.5', 'role' => 'admin',
      'country' => 'GB', 'visits' => '12', 'ratio' => '0.75', 'enabled' => 'true'
    }.freeze
  end

  def run(iterations: Integer(ENV.fetch('ITERATIONS', DEFAULT_ITERATIONS.to_s)))
    raise ArgumentError, 'ITERATIONS must be positive' unless iterations.positive?

    timings = ENGINES.to_h do |engine|
      [engine, isolated_measurement(engine, iterations: iterations)]
    end

    print_results(timings)
  end

  def isolated_measurement(engine, iterations:)
    environment = sanitized_environment.merge(
      ENGINE_ENV => engine,
      'ITERATIONS' => iterations.to_s
    )
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, '-Ilib', __FILE__)
    raise "#{engine} concurrency benchmark failed:\n#{stderr}" unless status.success?

    JSON.parse(stdout).fetch('timings')
  rescue JSON::ParserError => e
    raise "#{engine} concurrency benchmark returned invalid JSON: #{e.message}"
  end

  def sanitized_environment
    ENV.to_h.reject do |key, _|
      key.start_with?('BUNDLE_', 'BUNDLER_') ||
        %w[RUBYLIB RUBYOPT ITERATIONS CONCURRENCY_BENCHMARK_ENGINE].include?(key)
    end
  end

  def run_engine(engine, iterations:)
    contract = contract_for(engine)
    timings = {}

    THREAD_COUNTS.each do |thread_count|
      timings[thread_count.to_s] = Benchmark.realtime do
        benchmark_threads(contract, input, thread_count, iterations: iterations)
      end
    end

    puts JSON.generate('engine' => engine, 'timings' => timings)
  end

  def print_results(timings)
    puts 'engine/threads real seconds'
    ENGINES.each do |engine|
      THREAD_COUNTS.each do |thread_count|
        puts format('%<label>-14s %<seconds>10.6f',
                    label: "#{engine}-#{thread_count}t", seconds: timings.fetch(engine).fetch(thread_count.to_s))
      end
    end

    puts "\nNormalized scaling (higher is better; 1.00x means no parallel speedup):"
    ENGINES.each do |engine|
      engine_timings = timings.fetch(engine)
      single_thread_time = engine_timings.fetch('1')
      scaling = THREAD_COUNTS.to_h do |thread_count|
        [thread_count, (single_thread_time * thread_count) / engine_timings.fetch(thread_count.to_s)]
      end
      values = THREAD_COUNTS.map { |count| "#{count}t=#{format('%.2f', scaling.fetch(count))}x" }
      puts "#{engine}: #{values.join(', ')}"
    end
  end
end
# rubocop:enable Metrics/ModuleLength

if $PROGRAM_NAME == __FILE__
  iterations = Integer(ENV.fetch('ITERATIONS', ConcurrencyBenchmark::DEFAULT_ITERATIONS.to_s))
  engine = ENV.fetch(ConcurrencyBenchmark::ENGINE_ENV, nil)

  if engine
    ConcurrencyBenchmark.run_engine(engine, iterations: iterations)
  else
    ConcurrencyBenchmark.run(iterations: iterations)
  end
end
