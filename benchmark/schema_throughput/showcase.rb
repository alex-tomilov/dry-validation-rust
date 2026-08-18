# frozen_string_literal: true

module SchemaThroughput
  module Showcase
    module_function

    def print_scenario(scenario, fixed_results, engines, settings, index:)
      require 'benchmark/ips'
      require 'memory_profiler'

      puts '=' * 78
      puts "  #{index}. #{scenario_title(scenario.fetch('name'))}"
      puts "  #{scenario.fetch('description')}"
      puts '-' * 78
      contracts = engines.map do |engine|
        contract = FixedRun.build_contract(engine.fetch(:contract_class), scenario, settings)
        engine.merge(
          label: "#{engine.fetch(:engine)} v#{engine.fetch(:version)}",
          invoke: FixedRun.contract_invocation(contract, scenario.fetch('payloads'))
        )
      end

      print_ips(contracts, settings)
      print_memory_profiles(contracts, settings)
      print_peak_rss(fixed_results)
    end

    def print_ips(contracts, settings)
      puts "  Throughput — Benchmark.ips (#{settings.ips_warmup}s warmup, #{settings.ips_time}s measurement)"
      Benchmark.ips do |benchmark|
        benchmark.config(time: settings.ips_time, warmup: settings.ips_warmup)
        contracts.each { |engine| benchmark.report(engine.fetch(:label), &engine.fetch(:invoke)) }
        benchmark.compare! if contracts.length > 1
      end
    end
    private_class_method :print_ips

    def print_memory_profiles(contracts, settings)
      puts "\n  Memory — MemoryProfiler (#{settings.memory_profile_iterations} validations per engine)"
      contracts.each do |engine|
        print_memory_profile(engine.fetch(:label), memory_profile(engine.fetch(:invoke), settings))
      end
    end
    private_class_method :print_memory_profiles

    def memory_profile(invoke, settings)
      GC.start
      report = MemoryProfiler.report { settings.memory_profile_iterations.times { invoke.call } }
      {
        allocated_objects_per_validation: report.total_allocated.fdiv(settings.memory_profile_iterations),
        allocated_bytes_per_validation: report.total_allocated_memsize.fdiv(settings.memory_profile_iterations),
        retained_objects: report.total_retained,
        retained_bytes: report.total_retained_memsize
      }
    end
    private_class_method :memory_profile

    def print_memory_profile(engine, profile)
      puts "    #{engine}"
      puts format(
        '      allocated  %<objects>.2f objects/validation  ·  %<bytes>.1f B/validation',
        objects: profile.fetch(:allocated_objects_per_validation), bytes: profile.fetch(:allocated_bytes_per_validation)
      )
      puts "      retained   #{profile.fetch(:retained_objects)} objects  ·  #{profile.fetch(:retained_bytes)} B"
    end
    private_class_method :print_memory_profile

    def print_peak_rss(results)
      labels = results.map { |result| engine_label(result) }
      label_width = labels.map(&:length).max

      puts "\n  Peak RSS — fixed iteration run"
      results.zip(labels).each do |result, engine|
        rss = result.fetch('peak_rss_kb')
        value = rss ? "#{rss} kB" : 'unavailable'
        puts "    #{engine.ljust(label_width)}  #{value}"
      end
    end
    private_class_method :print_peak_rss

    def scenario_title(name)
      name.split('_').map(&:capitalize).join(' ')
    end
    private_class_method :scenario_title

    def engine_label(result)
      "#{result.fetch('engine')} v#{result.fetch('version')}"
    end
    private_class_method :engine_label
  end
end
