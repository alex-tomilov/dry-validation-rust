# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'time'
require_relative 'metadata'
require_relative 'scenarios'
require_relative 'settings'

module SchemaThroughput
  module Publication
    Config = Data.define(
      :runs,
      :target_seconds,
      :calibration_iterations,
      :latency_samples,
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
          runs: Integer(environment.fetch('RUNS', '5')),
          target_seconds: Float(environment.fetch('TARGET_SECONDS', '5')),
          calibration_iterations: Integer(environment.fetch('CALIBRATION_N', '500')),
          latency_samples: Integer(environment.fetch('LATENCY_SAMPLES', '500')),
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
          'latency_samples' => latency_samples,
          'scenario_filter' => scenario_filter,
          'validate_keys' => validate_keys,
          'upstream_version' => upstream_version
        }
      end
    end

    module Statistics
      module_function

      def summary(values)
        numeric = values.compact.map(&:to_f)
        return nil if numeric.empty?

        median = median(numeric)
        deviations = numeric.map { |value| (value - median).abs }
        {
          'values' => numeric,
          'median' => median,
          'min' => numeric.min,
          'max' => numeric.max,
          'mad' => median(deviations),
          'mad_pct' => percentage(median(deviations), median),
          'spread_pct' => percentage(numeric.max - numeric.min, median)
        }
      end

      def median(values)
        sorted = values.sort
        middle = sorted.length / 2
        return sorted.fetch(middle) if sorted.length.odd?

        (sorted.fetch(middle - 1) + sorted.fetch(middle)).fdiv(2)
      end

      def percentage(value, denominator)
        return 0.0 if denominator.zero?

        value.fdiv(denominator) * 100.0
      end
    end

    # rubocop:disable Metrics/ClassLength
    class Runner
      MIN_ITERATIONS = 500
      MAX_ITERATIONS = 2_000_000
      MIN_CALIBRATION_SECONDS = 0.25
      TARGET_CALIBRATION_SECONDS = 0.5
      ENGINE_ALIASES = %w[rust upstream].freeze

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
        announce(state, checkpoint_path, scenarios)

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

        raise <<~MESSAGE
          Refusing to collect publication evidence from a dirty working tree.
          Commit/stash the changes first, or set ALLOW_DIRTY=true for an exploratory run
          that must not be used as canonical README/CV evidence.
        MESSAGE
      end

      def load_or_initialize_state(metadata, scenarios)
        return initial_state(metadata, scenarios) unless config.resume_from

        state = JSON.parse(File.read(config.resume_from))
        protocol_keys = config.protocol.keys
        unless state.fetch('protocol').slice(*protocol_keys) == config.protocol
          raise 'RESUME_FROM protocol does not match the current benchmark settings'
        end
        unless state.dig('environment', 'git_sha') == metadata['git_sha']
          raise 'RESUME_FROM was recorded for a different Git commit'
        end

        state
      end

      def initial_state(metadata, scenarios)
        {
          'benchmark' => 'schema_throughput_publication',
          'schema_version' => 1,
          'environment' => metadata,
          'protocol' => config.protocol.merge(
            'engines' => ENGINE_ALIASES,
            'process_isolation' => 'fresh Ruby process per engine/scenario/run',
            'engine_order' => 'alternates by run',
            'scenario_order' => 'reverses every other run',
            'outlier_policy' => 'never discard automatically; report all successful runs',
            'retry_policy' => "retry execution failures up to #{config.retries} times; never retry merely because a result is slow"
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
        File.join(config.output_dir, "publication-#{timestamp}-#{sha}.checkpoint.json")
      end

      def announce(state, checkpoint_path, scenarios)
        total_measurements = config.runs * scenarios.length * ENGINE_ALIASES.length
        completed_measurements = state.fetch('measurements').length
        remaining_seconds = (total_measurements - completed_measurements) * config.target_seconds

        warn "Publication benchmark: #{state.dig('environment', 'git_short_sha') || 'unknown commit'}"
        warn "Checkpoint: #{checkpoint_path}"
        warn "Plan: #{total_measurements} isolated measurements (#{config.runs} runs × #{scenarios.length} scenarios × #{ENGINE_ALIASES.length} engines); about #{format_duration(remaining_seconds)} of measured work remaining, plus calibration, warmups, and process startup."
        warn "Measurement progress: #{completed_measurements}/#{total_measurements} complete"
        warn "Resume after an interruption with: RESUME_FROM=#{checkpoint_path} bundle exec script/benchmark-publication"
      end

      def announce_measurement_progress(state, scenarios)
        total_measurements = config.runs * scenarios.length * ENGINE_ALIASES.length
        completed_measurements = state.fetch('measurements').length
        warn "Measurement progress: #{completed_measurements}/#{total_measurements} complete"
      end

      def format_duration(seconds)
        minutes, seconds = seconds.round.divmod(60)
        return "#{seconds}s" if minutes.zero?

        "#{minutes}m #{seconds}s"
      end

      def calibrate!(state, scenarios, checkpoint_path)
        scenarios.each do |scenario|
          name = scenario.fetch('name')
          next if state.fetch('calibrations').key?(name)

          calibration = calibrate_scenario(name)
          state.fetch('calibrations')[name] = calibration
          write_checkpoint(checkpoint_path, state)
          warn "Calibration progress: #{state.fetch('calibrations').length}/#{scenarios.length} scenarios complete"
        end
      end

      def calibrate_scenario(scenario)
        ENGINE_ALIASES.to_h do |engine|
          [engine, calibrate_engine(engine, scenario)]
        end
      end

      def calibrate_engine(engine, scenario)
        first = child_measurement(
          engine: engine, scenario: scenario,
          iterations: config.calibration_iterations,
          warmup: [config.calibration_iterations / 5, 50].max,
          latency_samples: [config.latency_samples, 50].min
        )
        elapsed = first.fetch('elapsed_seconds')
        calibration = first

        if elapsed < MIN_CALIBRATION_SECONDS
          scaled_iterations = [
            (config.calibration_iterations * TARGET_CALIBRATION_SECONDS / elapsed).ceil,
            100_000
          ].min
          calibration = child_measurement(
            engine: engine, scenario: scenario,
            iterations: scaled_iterations,
            warmup: (scaled_iterations / 10).clamp(100, 5_000),
            latency_samples: [config.latency_samples, 50].min
          )
        end

        iterations = (calibration.fetch('throughput_per_second') * config.target_seconds).round
        iterations = iterations.clamp(MIN_ITERATIONS, MAX_ITERATIONS)
        {
          'throughput_per_second' => calibration.fetch('throughput_per_second'),
          'calibration_elapsed_seconds' => calibration.fetch('elapsed_seconds'),
          'publication_iterations' => iterations,
          'publication_warmup_iterations' => warmup_for(iterations)
        }
      end

      def measure!(state, scenarios, checkpoint_path)
        (1..config.runs).each do |run_index|
          ordered_scenarios = run_index.even? ? scenarios.reverse : scenarios
          engine_order = run_index.even? ? %w[upstream rust] : %w[rust upstream]

          ordered_scenarios.each do |scenario|
            name = scenario.fetch('name')
            scenario_calibrations = state.fetch('calibrations').fetch(name)
            engine_order.each do |engine|
              next if measurement_exists?(state, run_index, name, engine)

              result = child_measurement(
                engine: engine,
                scenario: name,
                iterations: scenario_calibrations.fetch(engine).fetch('publication_iterations'),
                warmup: scenario_calibrations.fetch(engine).fetch('publication_warmup_iterations'),
                latency_samples: config.latency_samples
              )
              state.fetch('measurements') << result.merge(
                'run' => run_index,
                'requested_engine' => engine,
                'engine_order' => engine_order
              )
              write_checkpoint(checkpoint_path, state)
              announce_measurement_progress(state, scenarios)
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

      def child_measurement(engine:, scenario:, iterations:, warmup:, latency_samples:)
        payload = with_retries(engine: engine, scenario: scenario) do
          env = sanitized_environment.merge(
            'FORMAT' => 'json',
            'ENGINE' => engine,
            'SCENARIO' => scenario,
            'N' => iterations.to_s,
            'WARMUP' => warmup.to_s,
            'LATENCY_SAMPLES' => latency_samples.to_s,
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

          warn "Retrying #{engine}/#{scenario} after execution failure (attempt #{attempts}/#{config.retries + 1}): #{e.message.lines.first&.strip}"
          retry
        end
      end

      def sanitized_environment
        ENV.to_h.reject do |key, _|
          key.start_with?('BUNDLE_', 'BUNDLER_') || %w[RUBYLIB RUBYOPT ENGINE FORMAT SCENARIO N WARMUP LATENCY_SAMPLES UPSTREAM_VERSION].include?(key)
        end
      end

      def warmup_for(iterations)
        (iterations / 20).clamp(100, 5_000)
      end

      def summarize(state, scenarios)
        scenarios.to_h do |scenario|
          name = scenario.fetch('name')
          measurements = state.fetch('measurements').select { |entry| entry.fetch('scenario') == name }
          rust = measurements.select { |entry| entry.fetch('requested_engine') == 'rust' }.sort_by { |entry| entry.fetch('run') }
          upstream = measurements.select { |entry| entry.fetch('requested_engine') == 'upstream' }.sort_by { |entry| entry.fetch('run') }
          [name, summary_for(scenario, rust, upstream)]
        end
      end

      def summary_for(scenario, rust, upstream)
        paired = paired_measurements(rust, upstream)
        speedups = paired.map { |rust_entry, upstream_entry| rust_entry.fetch('throughput_per_second') / upstream_entry.fetch('throughput_per_second') }
        rss_reductions = paired.filter_map { |rust_entry, upstream_entry| rss_reduction(rust_entry, upstream_entry) }
        allocation_reductions = paired.map { |rust_entry, upstream_entry| allocation_reduction(rust_entry, upstream_entry) }

        {
          'description' => scenario.fetch('description'),
          'rust_throughput_per_second' => Statistics.summary(rust.map { |entry| entry.fetch('throughput_per_second') }),
          'upstream_throughput_per_second' => Statistics.summary(upstream.map { |entry| entry.fetch('throughput_per_second') }),
          'throughput_speedup' => Statistics.summary(speedups),
          'rust_p95_latency_us' => Statistics.summary(rust.map { |entry| entry.dig('latency_us', 'p95') }),
          'upstream_p95_latency_us' => Statistics.summary(upstream.map { |entry| entry.dig('latency_us', 'p95') }),
          'ruby_allocation_reduction_pct' => Statistics.summary(allocation_reductions),
          'peak_rss_reduction_pct' => Statistics.summary(rss_reductions)
        }
      end

      def paired_measurements(rust, upstream)
        upstream_by_run = upstream.to_h { |entry| [entry.fetch('run'), entry] }
        rust.filter_map do |entry|
          upstream_entry = upstream_by_run[entry.fetch('run')]
          [entry, upstream_entry] if upstream_entry
        end
      end

      def rss_reduction(rust, upstream)
        rust_rss = rust['peak_rss_kb']
        upstream_rss = upstream['peak_rss_kb']
        return unless rust_rss && upstream_rss&.positive?

        (1.0 - rust_rss.fdiv(upstream_rss)) * 100.0
      end

      def allocation_reduction(rust, upstream)
        rust_allocations = rust.fetch('ruby_allocated_objects_per_call')
        upstream_allocations = upstream.fetch('ruby_allocated_objects_per_call')
        (1.0 - rust_allocations.fdiv(upstream_allocations)) * 100.0
      end

      def write_checkpoint(path, state)
        FileUtils.mkdir_p(File.dirname(path))
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
        lines << '# Schema throughput publication benchmark'
        lines << ''
        lines << "- Commit: `#{metadata['git_sha'] || 'unknown'}`#{' (dirty)' if metadata['git_dirty']}"
        lines << "- Recorded: #{state['completed_at'] || metadata['recorded_at']}"
        lines << "- Ruby: #{metadata['ruby']}"
        lines << "- CPU: #{metadata['cpu_model'] || metadata['host_cpu']}"
        lines << "- OS/platform: #{metadata['host_os']} / #{metadata['ruby_platform']}"
        lines << "- Rust: #{metadata['rustc'] || 'unavailable'}"
        upstream = state.fetch('measurements', []).find { |entry| entry['requested_engine'] == 'upstream' }
        if upstream
          gems = upstream.fetch('loaded_gems', {})
          lines << "- Upstream gems: dry-validation #{gems['dry-validation'] || protocol['upstream_version']}, dry-schema #{gems['dry-schema'] || 'unknown'}, dry-types #{gems['dry-types'] || 'unknown'}"
        else
          lines << "- Upstream target: dry-validation #{protocol['upstream_version']}"
        end
        lines << "- Runs: #{protocol['runs']} per engine/scenario"
        lines << "- Target measured time: ~#{protocol['target_seconds']}s per calibrated engine run"
        lines << '- Process isolation: fresh Ruby process per engine/scenario/run'
        lines << '- Outliers: never removed automatically'
        lines << ''
        lines << '| Scenario | Rust validations/s median (range) | Upstream median (range) | Median speedup (range) | Throughput MAD | Peak RSS reduction | Ruby allocation reduction |'
        lines << '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'
        state.fetch('summary').each do |name, summary|
          rust = summary.fetch('rust_throughput_per_second')
          upstream = summary.fetch('upstream_throughput_per_second')
          speedup = summary.fetch('throughput_speedup')
          rss = summary['peak_rss_reduction_pct']
          allocations = summary.fetch('ruby_allocation_reduction_pct')
          lines << "#{[
            "| `#{name}`",
            format_rate(rust),
            format_rate(upstream),
            format_ratio(speedup),
            format('%<rust>.1f%% / %<upstream>.1f%%', rust: rust.fetch('mad_pct'), upstream: upstream.fetch('mad_pct')),
            format_percent(rss),
            format_percent(allocations)
          ].join(' | ')} |"
        end
        lines << ''
        lines << '> Ruby allocation reduction refers to Ruby object allocations measured with `GC.stat`; it is not total native memory usage. Peak RSS is process high-water memory. Negative percentages mean the Rust-backed path used more of that metric.'
        lines << ''
        lines << '> Treat rows with wide ranges or high MAD as unstable and rerun on a quieter host. Do not replace an inconvenient run merely because it lowers the claimed speedup.'
        lines << ''
        lines.join("\n")
      end

      def format_rate(summary)
        format('%<median>.0f (%<minimum>.0f–%<maximum>.0f)', median: summary.fetch('median'), minimum: summary.fetch('min'), maximum: summary.fetch('max'))
      end
      private_class_method :format_rate

      def format_ratio(summary)
        format('%<median>.2f× (%<minimum>.2f–%<maximum>.2f)', median: summary.fetch('median'), minimum: summary.fetch('min'), maximum: summary.fetch('max'))
      end
      private_class_method :format_ratio

      def format_percent(summary)
        return 'n/a' unless summary

        format('%<median>.1f%% (%<minimum>.1f–%<maximum>.1f)', median: summary.fetch('median'), minimum: summary.fetch('min'), maximum: summary.fetch('max'))
      end
      private_class_method :format_percent
    end
  end
end
