#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "optparse"

require_relative "support/workloads"

module DryValidationRustBenchmark
  class Worker
    PROJECT_ROOT = File.expand_path("..", __dir__)

    def initialize(argv)
      @options = {
        iterations: nil,
        warmup_iterations: nil
      }
      parse!(argv)
    end

    def call
      engine = load_engine
      workload = Workloads.fetch(@options.fetch(:workload))
      contract = workload.build_contract(engine.fetch(:base_class))
      inputs = workload.inputs_for(@options.fetch(:distribution))
      preflight = inputs.map { |input| canonical_outcome(contract.call(input)) }
      expected_successes = count_expected(preflight, true, @options.fetch(:iterations))
      expected_failures = @options.fetch(:iterations) - expected_successes

      @options.fetch(:warmup_iterations).times do |index|
        contract.call(inputs.fetch(index % inputs.length))
      end

      GC.start
      gc_before = GC.stat
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      successes = 0
      failures = 0
      @options.fetch(:iterations).times do |index|
        if contract.call(inputs.fetch(index % inputs.length)).success?
          successes += 1
        else
          failures += 1
        end
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      gc_after = GC.stat

      unless successes == expected_successes && failures == expected_failures
        abort "measured validity counts differ from preflight expectations"
      end

      outcome_checksum = Digest::SHA256.hexdigest(
        JSON.generate(
          "workload" => workload.name,
          "distribution" => @options.fetch(:distribution),
          "iterations" => @options.fetch(:iterations),
          "preflight" => preflight,
          "successes" => successes,
          "failures" => failures
        )
      )

      {
        "schema_version" => 1,
        "engine" => engine.fetch(:name),
        "engine_version" => engine.fetch(:version),
        "dry_schema_version" => engine[:dry_schema_version],
        "ruby" => RUBY_DESCRIPTION,
        "ruby_platform" => RUBY_PLATFORM,
        "workload" => workload.name,
        "workload_description" => workload.description,
        "distribution" => @options.fetch(:distribution),
        "iterations" => @options.fetch(:iterations),
        "warmup_iterations" => @options.fetch(:warmup_iterations),
        "elapsed_seconds" => elapsed,
        "throughput_per_second" => @options.fetch(:iterations) / elapsed,
        "allocated_objects" => gc_after.fetch(:total_allocated_objects) - gc_before.fetch(:total_allocated_objects),
        "gc_count" => gc_after.fetch(:count) - gc_before.fetch(:count),
        "gc_time_milliseconds" => gc_after.fetch(:time) - gc_before.fetch(:time),
        "processed_count" => successes + failures,
        "success_count" => successes,
        "failure_count" => failures,
        "preflight_outcomes" => preflight,
        "outcome_checksum" => outcome_checksum
      }
    end

    private

    def parse!(argv)
      parser = OptionParser.new do |options|
        options.on("--engine NAME") { |value| @options[:engine] = value }
        options.on("--workload NAME") { |value| @options[:workload] = value }
        options.on("--distribution NAME") { |value| @options[:distribution] = value }
        options.on("--iterations N", Integer) { |value| @options[:iterations] = value }
        options.on("--warmup N", Integer) { |value| @options[:warmup_iterations] = value }
      end
      parser.parse!(argv)
      abort parser.to_s unless argv.empty?

      %i[engine workload distribution iterations warmup_iterations].each do |key|
        abort "missing --#{key.to_s.tr("_", "-")}" if @options[key].nil?
      end
      abort "iterations must be positive" unless @options.fetch(:iterations).positive?
      abort "warmup must be non-negative" if @options.fetch(:warmup_iterations).negative?
      abort "unknown distribution" unless %w[valid invalid mixed].include?(@options.fetch(:distribution))
    rescue OptionParser::ParseError => error
      abort error.message
    end

    def load_engine
      case @options.fetch(:engine)
      when "rust"
        $LOAD_PATH.unshift(File.join(PROJECT_ROOT, "lib"))
        require "dry/validation/rust"
        abort "upstream dry-validation was loaded in the Rust worker" if Gem.loaded_specs.key?("dry-validation")

        {
          name: "dry-validation-rust",
          version: Dry::Validation::Rust::VERSION,
          base_class: Dry::Validation::Rust::Contract
        }
      when "upstream"
        gem "dry-validation", "1.11.1"
        gem "dry-schema", "1.16.0"
        require "dry/validation"
        abort "project safe namespace was loaded in the upstream worker" if defined?(Dry::Validation::Rust)

        {
          name: "dry-validation",
          version: Gem.loaded_specs.fetch("dry-validation").version.to_s,
          dry_schema_version: Gem.loaded_specs.fetch("dry-schema").version.to_s,
          base_class: Dry::Validation::Contract
        }
      else
        abort "unknown engine: #{@options.fetch(:engine).inspect}"
      end
    end

    def canonical_outcome(result)
      {
        "success" => result.success?,
        "output" => canonical_value(result.to_h),
        "error_paths" => result.errors.map { |message| Array(message.path).map(&:to_s) }.sort
      }
    end

    def canonical_value(value)
      case value
      when Hash
        value.to_h { |key, nested| [key.to_s, canonical_value(nested)] }.sort.to_h
      when Array
        value.map { |nested| canonical_value(nested) }
      when Symbol
        value.to_s
      else
        value
      end
    end

    def count_expected(preflight, success, iterations)
      iterations.times.count { |index| preflight.fetch(index % preflight.length).fetch("success") == success }
    end
  end
end

puts JSON.pretty_generate(DryValidationRustBenchmark::Worker.new(ARGV).call)
