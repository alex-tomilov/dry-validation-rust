# frozen_string_literal: true

require 'benchmark'
require_relative 'process_memory'

module SchemaThroughput
  # This module is a single measurement helper; splitting it would separate closely coupled metrics.
  # rubocop:disable Metrics/ModuleLength
  module FixedRun
    module_function

    def github_action_benchmark_results(results)
      results.map do |result|
        memory = result.fetch('process_memory', {})
        after = memory.fetch('after', {})
        {
          'name' => "#{result.fetch('engine')} #{result.fetch('scenario')} p95 latency",
          'unit' => 'microseconds',
          'value' => result.fetch('latency_us').fetch('p95'),
          'extra' => [
            "throughput_per_second: #{result.fetch('throughput_per_second')}",
            "ruby_allocated_objects_per_call: #{result.fetch('ruby_allocated_objects_per_call')}",
            "peak_rss_kb: #{result['peak_rss_kb']}",
            "rss_after_kb: #{after['rss_kb']}",
            "pss_after_kb: #{after['pss_kb']}",
            "uss_after_kb: #{after['uss_kb']}"
          ].join("\n")
        }
      end
    end

    def benchmark_engine(contract_class, engine:, version:, scenarios:, settings:)
      scenarios.map do |scenario|
        contract = build_contract(contract_class, scenario, settings)
        measure(contract, scenario.fetch('payloads'), settings).merge(
          'scenario' => scenario.fetch('name'),
          'description' => scenario.fetch('description'),
          'engine' => engine,
          'version' => version,
          'ruby' => RUBY_DESCRIPTION,
          'loaded_gems' => loaded_gem_versions
        )
      end
    end

    def loaded_gem_versions
      %w[dry-validation dry-schema dry-types].each_with_object({}) do |name, versions|
        spec = Gem.loaded_specs[name]
        versions[name] = spec.version.to_s if spec
      end
    end
    private_class_method :loaded_gem_versions

    def build_contract(contract_class, scenario, settings)
      configuration = "config.validate_keys = true\n" if settings.validate_keys
      rules = scenario.fetch('rules_source', '')
      definition = <<~RUBY
        Class.new(#{contract_class}) do
        #{configuration}params do
        #{scenario.fetch('source')}
        end
        #{rules}
        end
      RUBY
      eval(definition, TOPLEVEL_BINDING, __FILE__, __LINE__).new # rubocop:disable Security/Eval
    end

    def contract_invocation(contract, payloads)
      payload_index = 0
      lambda do
        payload = payloads.fetch(payload_index % payloads.length)
        payload_index += 1
        contract.call(payload)
      end
    end

    def measure(contract, payloads, settings)
      invoke = contract_invocation(contract, payloads)

      settings.fixed_run_warmup_iterations.times { invoke.call }
      GC.start
      process_memory_before = ProcessMemory.snapshot
      before = GC.stat
      elapsed = Benchmark.realtime { settings.fixed_run_iterations.times { invoke.call } }
      after = GC.stat
      process_memory_after = ProcessMemory.snapshot
      process_memory = ProcessMemory.measurement(before: process_memory_before, after: process_memory_after)
      samples = latency_samples(invoke, settings)
      memory_profile = memory_profile(invoke, settings) if settings.memory_profile

      {
        'iterations' => settings.fixed_run_iterations,
        'warmup_iterations' => settings.fixed_run_warmup_iterations,
        'latency_samples' => samples.length,
        'elapsed_seconds' => elapsed,
        'throughput_per_second' => settings.fixed_run_iterations / elapsed,
        'latency_us' => latency_percentiles(samples),
        'ruby_allocated_objects_per_call' => allocated_objects_per_call(before, after, settings),
        'peak_rss_kb' => process_memory['peak_rss_kb'],
        'process_memory' => process_memory
      }.tap { |result| result['memory_profile'] = memory_profile if memory_profile }
    end

    def allocated_objects_per_call(before, after, settings)
      allocated = after[:total_allocated_objects] - before[:total_allocated_objects]
      allocated.fdiv(settings.fixed_run_iterations)
    end
    private_class_method :allocated_objects_per_call

    def memory_profile(invoke, settings)
      require 'memory_profiler'

      GC.start
      report = MemoryProfiler.report { settings.memory_profile_iterations.times { invoke.call } }
      {
        'iterations' => settings.memory_profile_iterations,
        'total_allocated_objects' => report.total_allocated,
        'total_allocated_bytes' => report.total_allocated_memsize,
        'retained_objects' => report.total_retained,
        'retained_bytes' => report.total_retained_memsize
      }
    end
    private_class_method :memory_profile

    def latency_samples(invoke, settings)
      Array.new([settings.latency_samples, settings.fixed_run_iterations].min) do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        invoke.call
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000_000
      end
    end
    private_class_method :latency_samples

    def latency_percentiles(samples)
      {
        'p50' => percentile(samples, 0.50),
        'p95' => percentile(samples, 0.95),
        'p99' => percentile(samples, 0.99)
      }
    end
    private_class_method :latency_percentiles

    def percentile(samples, percentile)
      index = ((samples.length - 1) * percentile).ceil
      samples.sort.fetch(index)
    end
    private_class_method :percentile
  end
  # rubocop:enable Metrics/ModuleLength
end
