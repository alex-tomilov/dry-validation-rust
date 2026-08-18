# frozen_string_literal: true

require 'benchmark'
require 'open3'

module SchemaThroughput
  module FixedRun
    module_function

    def benchmark_engine(contract_class, engine:, version:, scenarios:, settings:)
      scenarios.map do |scenario|
        contract = build_contract(contract_class, scenario, settings)
        measure(contract, scenario.fetch('payloads'), settings).merge(
          'scenario' => scenario.fetch('name'),
          'description' => scenario.fetch('description'),
          'engine' => engine,
          'version' => version,
          'ruby' => RUBY_DESCRIPTION
        )
      end
    end

    def build_contract(contract_class, scenario, settings)
      configuration = "config.validate_keys = true\n" if settings.validate_keys
      definition = "Class.new(#{contract_class}) do\n#{configuration}params do\n#{scenario.fetch('source')}\nend\nend"
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
      before = GC.stat
      elapsed = Benchmark.realtime { settings.fixed_run_iterations.times { invoke.call } }
      after = GC.stat
      samples = latency_samples(invoke, settings)

      {
        'iterations' => settings.fixed_run_iterations,
        'warmup_iterations' => settings.fixed_run_warmup_iterations,
        'latency_samples' => samples.length,
        'elapsed_seconds' => elapsed,
        'throughput_per_second' => settings.fixed_run_iterations / elapsed,
        'latency_us' => latency_percentiles(samples),
        'ruby_allocated_objects_per_call' => (after[:total_allocated_objects] - before[:total_allocated_objects]).fdiv(settings.fixed_run_iterations),
        'peak_rss_kb' => rss_kb
      }
    end

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

    def rss_kb
      status = '/proc/self/status'
      return Regexp.last_match(1).to_i if File.file?(status) && File.read(status) =~ /^VmHWM:\s+(\d+) kB$/

      output, = Open3.capture2('ps', '-o', 'rss=', '-p', Process.pid.to_s)
      Integer(output.strip)
    rescue Errno::ENOENT, ArgumentError
      nil
    end
    private_class_method :rss_kb
  end
end
