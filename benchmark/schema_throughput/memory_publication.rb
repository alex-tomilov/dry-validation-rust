# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'time'
require_relative 'metadata'
require_relative 'publication'
require_relative 'scenarios'
require_relative 'settings'

module SchemaThroughput
  # Equal-work process-memory evidence. Throughput publication intentionally uses
  # engine-specific iteration counts; memory publication intentionally does not.
  module MemoryPublication
    Config = Data.define(
      :runs,
      :target_seconds,
      :calibration_iterations,
      :retries,
      :scenario_filter,
      :validate_keys,
      :upstream_version,
      :allow_dirty,
      :output_dir,
      :resume_from
    ) do
      def self.from_environment(environment = ENV, project_root:)
        new(
          runs: Integer(environment.fetch('MEMORY_RUNS', '5')),
          target_seconds: Float(environment.fetch('MEMORY_TARGET_SECONDS', '2')),
          calibration_iterations: Integer(environment.fetch('MEMORY_CALIBRATION_N', '500')),
          retries: Integer(environment.fetch('RETRIES', '2')),
          scenario_filter: environment.fetch('SCENARIO', nil),
          validate_keys: environment.fetch('VALIDATE_KEYS', 'false') == 'true',
          upstream_version: environment.fetch('UPSTREAM_VERSION', DEFAULT_UPSTREAM_VERSION),
          allow_dirty: environment.fetch('ALLOW_DIRTY', 'false') == 'true',
          output_dir: File.expand_path(environment.fetch('OUTPUT_DIR', 'tmp/benchmarks'), project_root),
          resume_from: environment['RESUME_FROM'] && File.expand_path(environment['RESUME_FROM'], project_root)
        )
      end

      def protocol
        {
          'runs' => runs,
          'target_seconds' => target_seconds,
          'calibration_iterations' => calibration_iterations,
          'scenario_filter' => scenario_filter,
          'validate_keys' => validate_keys,
          'upstream_version' => upstream_version,
          'work_policy' => 'same iteration count and warmup for both engines within each scenario'
        }
      end
    end

    # rubocop:disable Metrics/ClassLength
    class Runner
      MIN_ITERATIONS = 500
      MAX_ITERATIONS = 500_000
      ENGINE_ORDER = %w[rust upstream].freeze

      attr_reader :config, :project_root, :benchmark_script

      def initialize(config:, project_root:)
        @config = config
        @project_root = project_root
        @benchmark_script = File.join(project_root, 'benchmark/schema_throughput.rb')
      end

      def run
        metadata = Metadata.snapshot(project_root: project_root)
        enforce_clean_tree!(metadata)
        scenarios = Scenarios.selected(config.scenario_filter)
        state = load_or_initialize_state(metadata, scenarios)
        checkpoint_path = checkpoint_path_for(state)

        calibrate!(state, scenarios, checkpoint_path)
        measure!(state, scenarios, checkpoint_path)
        state['summary'] = summarize(state, scenarios)
        state['completed_at'] = Time.now.utc.iso8601
        write_checkpoint(checkpoint_path, state)

        json_path = checkpoint_path.sub(/\.checkpoint\.json\z/, '.json')
        markdown_path = checkpoint_path.sub(/\.checkpoint\.json\z/, '.md')
        File.write(json_path, "#{JSON.pretty_generate(state)}\n")
        File.write(markdown_path, Markdown.render(state))
        [json_path, markdown_path, checkpoint_path]
      end

      private

      def enforce_clean_tree!(metadata)
        return unless metadata['git_dirty'] && !config.allow_dirty

        raise 'Refusing to collect publication memory evidence from a dirty working tree. Set ALLOW_DIRTY=true only for exploratory runs.'
      end

      def load_or_initialize_state(metadata, scenarios)
        return initial_state(metadata, scenarios) unless config.resume_from

        state = JSON.parse(File.read(config.resume_from))
        protocol_keys = config.protocol.keys
        unless state.fetch('protocol').slice(*protocol_keys) == config.protocol
          raise 'RESUME_FROM protocol does not match'
        end
        raise 'RESUME_FROM uses another Git commit' unless state.dig('environment', 'git_sha') == metadata['git_sha']

        state
      end

      def initial_state(metadata, scenarios)
        {
          'benchmark' => 'schema_memory_publication',
          'schema_version' => 1,
          'environment' => metadata,
          'protocol' => config.protocol.merge(
            'engines' => ENGINE_ORDER,
            'process_isolation' => 'fresh Ruby process per engine/scenario/run',
            'engine_order' => 'alternates by run',
            'outlier_policy' => 'never discard automatically'
          ),
          'scenarios' => scenarios.map { |scenario| scenario.slice('name', 'description') },
          'calibrations' => {},
          'measurements' => []
        }
      end

      def checkpoint_path_for(state)
        return config.resume_from if config.resume_from

        FileUtils.mkdir_p(config.output_dir)
        timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        sha = state.dig('environment', 'git_short_sha') || 'unknown'
        File.join(config.output_dir, "memory-publication-#{timestamp}-#{sha}.checkpoint.json")
      end

      def calibrate!(state, scenarios, checkpoint_path)
        scenarios.each do |scenario|
          name = scenario.fetch('name')
          next if state.fetch('calibrations').key?(name)

          probe = child_measurement(
            engine: 'upstream', scenario: name,
            iterations: config.calibration_iterations,
            warmup: [config.calibration_iterations / 5, 50].max
          )
          iterations = (probe.fetch('throughput_per_second') * config.target_seconds).round
          iterations = iterations.clamp(MIN_ITERATIONS, MAX_ITERATIONS)
          state.fetch('calibrations')[name] = {
            'upstream_throughput_per_second' => probe.fetch('throughput_per_second'),
            'iterations' => iterations,
            'warmup_iterations' => (iterations / 20).clamp(100, 5_000)
          }
          write_checkpoint(checkpoint_path, state)
        end
      end

      def measure!(state, scenarios, checkpoint_path)
        (1..config.runs).each do |run_index|
          ordered_scenarios = run_index.even? ? scenarios.reverse : scenarios
          engines = run_index.even? ? ENGINE_ORDER.reverse : ENGINE_ORDER

          ordered_scenarios.each do |scenario|
            name = scenario.fetch('name')
            calibration = state.fetch('calibrations').fetch(name)
            engines.each do |engine|
              next if measurement_exists?(state, run_index, name, engine)

              result = child_measurement(
                engine: engine,
                scenario: name,
                iterations: calibration.fetch('iterations'),
                warmup: calibration.fetch('warmup_iterations')
              )
              state.fetch('measurements') << result.merge(
                'run' => run_index,
                'requested_engine' => engine,
                'engine_order' => engines
              )
              write_checkpoint(checkpoint_path, state)
            end
          end
        end
      end

      def measurement_exists?(state, run_index, scenario, engine)
        state.fetch('measurements').any? do |measurement|
          measurement['run'] == run_index &&
            measurement['scenario'] == scenario &&
            measurement['requested_engine'] == engine
        end
      end

      def child_measurement(engine:, scenario:, iterations:, warmup:)
        payload = with_retries(engine: engine, scenario: scenario) do
          env = sanitized_environment.merge(
            'FORMAT' => 'json',
            'ENGINE' => engine,
            'SCENARIO' => scenario,
            'N' => iterations.to_s,
            'WARMUP' => warmup.to_s,
            'LATENCY_SAMPLES' => '1',
            'VALIDATE_KEYS' => config.validate_keys.to_s,
            'UPSTREAM_VERSION' => config.upstream_version
          )
          stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-Ilib', benchmark_script, chdir: project_root)
          raise "#{engine}/#{scenario} failed:\n#{stderr}" unless status.success?

          JSON.parse(stdout)
        end
        payload.fetch('results').fetch(0)
      end

      def with_retries(engine:, scenario:)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue JSON::ParserError, RuntimeError => e
          raise if attempts > config.retries

          warn "Retrying #{engine}/#{scenario} after execution failure: #{e.message.lines.first&.strip}"
          retry
        end
      end

      def sanitized_environment
        ENV.to_h.reject do |key, _|
          key.start_with?('BUNDLE_', 'BUNDLER_') ||
            %w[RUBYLIB RUBYOPT ENGINE FORMAT SCENARIO N WARMUP LATENCY_SAMPLES UPSTREAM_VERSION].include?(key)
        end
      end

      def summarize(state, scenarios)
        scenarios.to_h do |scenario|
          name = scenario.fetch('name')
          measurements = state.fetch('measurements').select { |entry| entry.fetch('scenario') == name }
          rust = measurements.select { |entry| entry.fetch('requested_engine') == 'rust' }
          upstream = measurements.select { |entry| entry.fetch('requested_engine') == 'upstream' }
          [name, summary_for(scenario, rust, upstream)]
        end
      end

      def summary_for(scenario, rust, upstream)
        paired = paired_measurements(rust, upstream)
        {
          'description' => scenario.fetch('description'),
          'rust_peak_rss_kb' => statistic(rust, 'peak_rss_kb'),
          'upstream_peak_rss_kb' => statistic(upstream, 'peak_rss_kb'),
          'peak_rss_reduction_pct' => reduction_statistic(paired, 'peak_rss_kb'),
          'rust_rss_after_kb' => memory_statistic(rust, 'rss_kb'),
          'upstream_rss_after_kb' => memory_statistic(upstream, 'rss_kb'),
          'rss_after_reduction_pct' => memory_reduction_statistic(paired, 'rss_kb'),
          'rust_pss_after_kb' => memory_statistic(rust, 'pss_kb'),
          'upstream_pss_after_kb' => memory_statistic(upstream, 'pss_kb'),
          'pss_after_reduction_pct' => memory_reduction_statistic(paired, 'pss_kb'),
          'rust_uss_after_kb' => memory_statistic(rust, 'uss_kb'),
          'upstream_uss_after_kb' => memory_statistic(upstream, 'uss_kb'),
          'uss_after_reduction_pct' => memory_reduction_statistic(paired, 'uss_kb'),
          'rust_peak_rss_growth_kb' => nested_statistic(rust, 'peak_rss_growth_kb'),
          'upstream_peak_rss_growth_kb' => nested_statistic(upstream, 'peak_rss_growth_kb'),
          'rust_rss_delta_kb' => delta_statistic(rust, 'rss_kb'),
          'upstream_rss_delta_kb' => delta_statistic(upstream, 'rss_kb'),
          'rust_pss_delta_kb' => delta_statistic(rust, 'pss_kb'),
          'upstream_pss_delta_kb' => delta_statistic(upstream, 'pss_kb'),
          'rust_uss_delta_kb' => delta_statistic(rust, 'uss_kb'),
          'upstream_uss_delta_kb' => delta_statistic(upstream, 'uss_kb'),
          'ruby_allocation_reduction_pct' => ruby_allocation_reduction(paired)
        }
      end

      def paired_measurements(rust, upstream)
        upstream_by_run = upstream.to_h { |entry| [entry.fetch('run'), entry] }
        rust.filter_map do |entry|
          other = upstream_by_run[entry.fetch('run')]
          [entry, other] if other
        end
      end

      def statistic(entries, key)
        Publication::Statistics.summary(entries.filter_map { |entry| entry[key] })
      end

      def memory_statistic(entries, key)
        Publication::Statistics.summary(entries.filter_map { |entry| entry.dig('process_memory', 'after', key) })
      end

      def nested_statistic(entries, key)
        Publication::Statistics.summary(entries.filter_map { |entry| entry.dig('process_memory', key) })
      end

      def delta_statistic(entries, key)
        Publication::Statistics.summary(entries.filter_map { |entry| entry.dig('process_memory', 'delta_kb', key) })
      end

      def reduction_statistic(paired, key)
        values = paired.filter_map { |rust, upstream| reduction(rust[key], upstream[key]) }
        Publication::Statistics.summary(values)
      end

      def memory_reduction_statistic(paired, key)
        values = paired.filter_map do |rust, upstream|
          reduction(
            rust.dig('process_memory', 'after', key),
            upstream.dig('process_memory', 'after', key)
          )
        end
        Publication::Statistics.summary(values)
      end

      def ruby_allocation_reduction(paired)
        values = paired.map do |rust, upstream|
          reduction(
            rust.fetch('ruby_allocated_objects_per_call'),
            upstream.fetch('ruby_allocated_objects_per_call')
          )
        end
        Publication::Statistics.summary(values)
      end

      def reduction(rust_value, upstream_value)
        return unless rust_value && upstream_value&.positive?

        (1.0 - rust_value.fdiv(upstream_value)) * 100.0
      end

      def write_checkpoint(path, state)
        temporary = "#{path}.tmp"
        File.write(temporary, "#{JSON.pretty_generate(state)}\n")
        File.rename(temporary, path)
      end
    end
    # rubocop:enable Metrics/ClassLength

    module Markdown
      module_function

      def render(state)
        metadata = state.fetch('environment')
        protocol = state.fetch('protocol')
        lines = []
        lines << '# Process-memory publication benchmark'
        lines << ''
        lines << "- Commit: `#{metadata['git_sha'] || 'unknown'}`#{' (dirty)' if metadata['git_dirty']}"
        lines << "- Recorded: #{state['completed_at'] || metadata['recorded_at']}"
        lines << "- Ruby: #{metadata['ruby']}"
        lines << "- CPU: #{metadata['cpu_model'] || metadata['host_cpu']}"
        lines << "- Runs: #{protocol['runs']} per engine/scenario"
        lines << '- Work policy: identical validation count and warmup for both engines within a scenario'
        lines << ''
        lines << '| Scenario | Rust peak RSS | Upstream peak RSS | Peak RSS reduction | ' \
                 'Rust PSS after | Upstream PSS after | PSS reduction | Rust USS after | ' \
                 'Upstream USS after | USS reduction | Ruby object reduction |'
        lines << '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        state.fetch('summary').each do |name, summary|
          lines << "#{[
            "| `#{name}`",
            format_kb(summary['rust_peak_rss_kb']),
            format_kb(summary['upstream_peak_rss_kb']),
            format_percent(summary['peak_rss_reduction_pct']),
            format_kb(summary['rust_pss_after_kb']),
            format_kb(summary['upstream_pss_after_kb']),
            format_percent(summary['pss_after_reduction_pct']),
            format_kb(summary['rust_uss_after_kb']),
            format_kb(summary['upstream_uss_after_kb']),
            format_percent(summary['uss_after_reduction_pct']),
            format_percent(summary['ruby_allocation_reduction_pct'])
          ].join(' | ')} |"
        end
        lines << ''
        lines << '## Growth during the measured validation loop'
        lines << ''
        lines << '| Scenario | Rust peak RSS growth | Upstream peak RSS growth | ' \
                 'Rust RSS delta | Upstream RSS delta | Rust PSS delta | Upstream PSS delta | ' \
                 'Rust USS delta | Upstream USS delta |'
        lines << '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        state.fetch('summary').each do |name, summary|
          lines << "#{[
            "| `#{name}`",
            format_kb(summary['rust_peak_rss_growth_kb']),
            format_kb(summary['upstream_peak_rss_growth_kb']),
            format_kb(summary['rust_rss_delta_kb']),
            format_kb(summary['upstream_rss_delta_kb']),
            format_kb(summary['rust_pss_delta_kb']),
            format_kb(summary['upstream_pss_delta_kb']),
            format_kb(summary['rust_uss_delta_kb']),
            format_kb(summary['upstream_uss_delta_kb'])
          ].join(' | ')} |"
        end
        lines << ''
        lines << '> Peak RSS is the whole-process resident high-water mark and includes Ruby, ' \
                 'Rust/native allocations, stacks, and resident mapped pages. PSS apportions ' \
                 'shared resident pages; USS counts private resident pages. PSS/USS are Linux-only.'
        lines << ''
        lines << '> None of RSS/PSS/USS is cumulative allocated bytes over time. Ruby object ' \
                 'reduction is a count from `GC.stat`, not a byte total. Use allocator ' \
                 'instrumentation such as heaptrack/Massif separately for cumulative traffic.'
        lines << ''
        lines.join("\n")
      end

      def format_kb(summary)
        return 'n/a' unless summary

        format('%<median>.0f kB (%<minimum>.0f–%<maximum>.0f)',
               median: summary.fetch('median'), minimum: summary.fetch('min'), maximum: summary.fetch('max'))
      end
      private_class_method :format_kb

      def format_percent(summary)
        return 'n/a' unless summary

        format('%<median>.1f%% (%<minimum>.1f–%<maximum>.1f)',
               median: summary.fetch('median'), minimum: summary.fetch('min'), maximum: summary.fetch('max'))
      end
      private_class_method :format_percent
    end
  end
end
