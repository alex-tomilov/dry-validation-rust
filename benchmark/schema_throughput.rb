# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require_relative 'schema_throughput/fixed_run'
require_relative 'schema_throughput/metadata'
require_relative 'schema_throughput/scenarios'
require_relative 'schema_throughput/settings'
require_relative 'schema_throughput/showcase'

# Runs the representative dry-validation-rust schema benchmark matrix.
#
# The default text report is intended for human comparison: it uses
# +benchmark-ips+ for warmed throughput measurements and comparisons, and
# +memory_profiler+ for Ruby allocation and retained-memory details. It also
# prints peak process RSS from the fixed-iteration run. Set +FORMAT=json+ for
# the stable machine-readable measurement payload, or
# +FORMAT=github-action-benchmark+ for the GitHub benchmark dashboard payload.
#
# The matrix covers eleven different validation shapes:
#
# - +small_form+: five valid scalar fields; a web-request baseline.
# - +medium_form+: 25 scalar fields with 80% valid calls.
# - +large_form+: 100 scalar fields with a 50/50 valid/invalid mix.
# - +nested_object+: ten nested hash levels.
# - +array_of_objects+: 100 objects, five fields each, with 90% valid calls.
# - +all_invalid+: 20 invalid scalar fields; useful for the error path.
# - +sparse_optional+: 50 optional fields with only 20% present.
# - +mixed_types+: integer, float, bool, and string coercion in one contract.
# - +array_of_primitives+: 500 integer values in one array.
# - +wide_nested_object+: 10 sibling hashes with 10 fields each.
# - +ruby_rules+: declarative schema work plus Ruby-owned dynamic rules.
#
# @example Compare both engines for a screenshot-ready small form report
#   SCENARIO=small_form ruby -Ilib benchmark/schema_throughput.rb
#
# @example Measure only the Rust-backed engine
#   ENGINE=rust SCENARIO=medium_form ruby -Ilib benchmark/schema_throughput.rb
#
# @example Measure only upstream dry-validation
#   ENGINE=upstream SCENARIO=nested_object ruby -Ilib benchmark/schema_throughput.rb
#
# @example Exercise the collection-validation path
#   ENGINE=rust SCENARIO=array_of_objects ruby -Ilib benchmark/schema_throughput.rb
#
# @example Include Ruby-owned rule execution
#   ENGINE=all SCENARIO=ruby_rules ruby -Ilib benchmark/schema_throughput.rb
#
# @example Focus on invalid input and error construction
#   ENGINE=all SCENARIO=all_invalid ruby -Ilib benchmark/schema_throughput.rb
#
# @example Enable strict unknown-key validation for the large-form scenario
#   VALIDATE_KEYS=true ENGINE=rust SCENARIO=large_form ruby -Ilib benchmark/schema_throughput.rb
#
# @example Produce the stable JSON payload for automation
#   FORMAT=json ENGINE=all SCENARIO=small_form ruby -Ilib benchmark/schema_throughput.rb
#
# @example Produce latency measurements for github-action-benchmark
#   FORMAT=github-action-benchmark ruby -Ilib benchmark/schema_throughput.rb
#
# @example Use a longer fixed run when collecting JSON evidence
#   FORMAT=json N=500000 WARMUP=10000 LATENCY_SAMPLES=500 ruby -Ilib benchmark/schema_throughput.rb
#
# @example Tune the text showcase without changing fixed-run settings
#   IPS_WARMUP=3 IPS_TIME=10 MEMORY_PROFILE_N=5000 SCENARIO=small_form ruby -Ilib benchmark/schema_throughput.rb
#
# @note +N+, +WARMUP+, and +LATENCY_SAMPLES+ configure the fixed run used for
#   JSON throughput, latency percentiles, allocations, and RSS. +IPS_WARMUP+
#   and +IPS_TIME+ affect text throughput only; +MEMORY_PROFILE_N+ affects
#   text allocation profiling only.
# @note For publication-quality repeated evidence, use
#   +script/benchmark-publication+ instead of manually copying one showcase run.
module SchemaThroughput
  module CLI
    module_function

    def rust_results(scenarios, settings)
      require 'dry/validation/rust'
      FixedRun.benchmark_engine(
        'Dry::Validation::Rust::Contract',
        engine: 'dry-validation-rust',
        version: Dry::Validation::Rust::VERSION,
        scenarios: scenarios,
        settings: settings
      )
    end

    def upstream_results(_scenarios, settings)
      source = <<~RUBY
        $LOAD_PATH.delete_if do |path|
          begin
            #{[settings.project_lib, File.realpath(settings.project_lib)].uniq.inspect}.include?(File.realpath(path))
          rescue Errno::ENOENT
            false
          end
        end
        gem 'dry-validation', #{settings.upstream_version.inspect}
        spec = Gem.loaded_specs.fetch('dry-validation')
        $LOAD_PATH.unshift(File.join(spec.full_gem_path, 'lib'))
        require 'dry/validation'
        load #{__FILE__.inspect}
        settings = SchemaThroughput::Settings.from_environment
        scenarios = SchemaThroughput::Scenarios.selected(settings.scenario_filter)
        puts JSON.generate(SchemaThroughput::FixedRun.benchmark_engine('Dry::Validation::Contract', engine: 'dry-validation', version: spec.version.to_s, scenarios: scenarios, settings: settings))
      RUBY
      env = ENV.to_h.reject { |key, _| key.start_with?('BUNDLE_', 'BUNDLER_') || %w[RUBYLIB RUBYOPT ENGINE FORMAT].include?(key) }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-e', source)
      return JSON.parse(stdout) if status.success?

      raise "upstream dry-validation benchmark failed. Install it for #{RbConfig.ruby} before running ENGINE=all or ENGINE=upstream.\n\n#{stderr}"
    end

    def requested_results(scenarios, settings)
      case settings.engine
      when 'rust', 'dry-validation-rust' then rust_results(scenarios, settings)
      when 'upstream', 'dry-validation' then upstream_results(scenarios, settings)
      when 'all', 'compare' then rust_results(scenarios, settings) + upstream_results(scenarios, settings)
      else abort "Unknown ENGINE=#{settings.engine.inspect}. Use all, rust, or upstream."
      end
    end

    def environment(settings)
      project_root = File.expand_path('..', settings.project_lib)
      Metadata.snapshot(project_root: project_root).merge(
        'iterations' => settings.fixed_run_iterations,
        'warmup_iterations' => settings.fixed_run_warmup_iterations,
        'latency_samples' => settings.latency_samples,
        'scenario_filter' => settings.scenario_filter,
        'validate_keys' => settings.validate_keys,
        'upstream_version_requested' => settings.upstream_version
      )
    end

    def upstream_contract_class(settings)
      $LOAD_PATH.delete_if do |path|
        [settings.project_lib, File.realpath(settings.project_lib)].include?(File.realpath(path))
      rescue Errno::ENOENT
        false
      end
      gem 'dry-validation', settings.upstream_version
      spec = Gem.loaded_specs.fetch('dry-validation')
      $LOAD_PATH.unshift(File.join(spec.full_gem_path, 'lib'))
      require 'dry/validation'
      Dry::Validation::Contract
    end

    def text_engines(settings)
      case settings.engine
      when 'rust', 'dry-validation-rust'
        require 'dry/validation/rust'
        [{ engine: 'dry-validation-rust', version: Dry::Validation::Rust::VERSION, contract_class: 'Dry::Validation::Rust::Contract' }]
      when 'upstream', 'dry-validation'
        upstream_contract_class(settings)
        [{ engine: 'dry-validation', version: Gem.loaded_specs.fetch('dry-validation').version.to_s, contract_class: 'Dry::Validation::Contract' }]
      when 'all', 'compare'
        require 'dry/validation/rust'
        upstream_contract_class(settings)
        [
          { engine: 'dry-validation-rust', version: Dry::Validation::Rust::VERSION, contract_class: 'Dry::Validation::Rust::Contract' },
          { engine: 'dry-validation', version: Gem.loaded_specs.fetch('dry-validation').version.to_s, contract_class: 'Dry::Validation::Contract' }
        ]
      else
        abort "Unknown ENGINE=#{settings.engine.inspect}. Use all, rust, or upstream."
      end
    end

    def run(settings = Settings.from_environment)
      Output.run(settings)
    end
  end

  module Output
    module_function

    def run(settings)
      scenarios = Scenarios.selected(settings.scenario_filter)
      results = CLI.requested_results(scenarios, settings)
      payload = { 'benchmark' => 'schema_throughput_matrix', 'environment' => CLI.environment(settings), 'results' => results }

      case settings.format
      when 'json'
        puts JSON.pretty_generate(payload)
      when 'github-action-benchmark'
        puts JSON.pretty_generate(FixedRun.github_action_benchmark_results(results))
      when 'text'
        engines = CLI.text_engines(settings)
        Showcase.print_environment(CLI.environment(settings), settings)
        scenarios.each_with_index do |scenario, index|
          scenario_results = results.select { |result| result.fetch('scenario') == scenario.fetch('name') }
          Showcase.print_scenario(scenario, scenario_results, engines, settings, index: index + 1)
          puts unless index == scenarios.length - 1
        end
      else
        abort "Unknown FORMAT=#{settings.format.inspect}. Use text, json, or github-action-benchmark."
      end
    end
  end
end

SchemaThroughput::CLI.run if __FILE__ == $PROGRAM_NAME
