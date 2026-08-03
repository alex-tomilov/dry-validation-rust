# frozen_string_literal: true

require 'benchmark'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

INPUT = {
  'id' => '42',
  'email' => 'jane@example.org',
  'active' => 'true',
  'tags' => %w[ruby rust validation],
  'profile' => { 'name' => 'Jane', 'age' => '31' }
}.freeze

ITERATIONS = Integer(ENV.fetch('N', '100000'))
WARMUP_ITERATIONS = Integer(ENV.fetch('WARMUP', '10000'))
ENGINE = ENV.fetch('ENGINE', 'all')
FORMAT = ENV.fetch('FORMAT', 'text')
PROJECT_LIB = File.expand_path('../lib', __dir__)

def measure(contract)
  WARMUP_ITERATIONS.times { contract.call(INPUT) }
  GC.start
  before = GC.stat
  elapsed = Benchmark.realtime { ITERATIONS.times { contract.call(INPUT) } }
  after = GC.stat

  {
    'iterations' => ITERATIONS,
    'warmup_iterations' => WARMUP_ITERATIONS,
    'elapsed' => elapsed,
    'throughput' => ITERATIONS / elapsed,
    'allocated_objects' => after[:total_allocated_objects] - before[:total_allocated_objects]
  }
end

def rust_result
  require 'dry/validation/rust'

  benchmark_contract = Class.new(Dry::Validation::Rust::Contract) do
    params do
      required(:id).value(:integer, gt?: 0)
      required(:email).filled(:string, format?: /@/)
      required(:active).value(:bool)
      required(:tags).array(:string)
      required(:profile).hash do
        required(:name).filled(:string)
        optional(:age).maybe(:integer)
      end
    end
  end

  measure(benchmark_contract.new).merge(
    'engine' => 'dry-validation-rust',
    'version' => Dry::Validation::Rust::VERSION,
    'ruby' => RUBY_DESCRIPTION
  )
end

def upstream_result
  source = <<~RUBY
    require "benchmark"
    require "json"

    input = #{INPUT.inspect}.freeze
    iterations = #{ITERATIONS}
    warmup_iterations = #{WARMUP_ITERATIONS}
    project_lib_paths = #{[PROJECT_LIB, File.realpath(PROJECT_LIB)].uniq.inspect}

    $LOAD_PATH.delete_if do |path|
      begin
        project_lib_paths.include?(File.realpath(path))
      rescue Errno::ENOENT
        project_lib_paths.include?(File.expand_path(path))
      end
    end

    gem "dry-validation"
    spec = Gem.loaded_specs.fetch("dry-validation")
    $LOAD_PATH.unshift(File.join(spec.full_gem_path, "lib"))
    require "dry/validation"

    benchmark_contract = Class.new(Dry::Validation::Contract) do
      params do
        required(:id).value(:integer, gt?: 0)
        required(:email).filled(:string, format?: /@/)
        required(:active).value(:bool)
        required(:tags).array(:string)
        required(:profile).hash do
          required(:name).filled(:string)
          optional(:age).maybe(:integer)
        end
      end
    end

    contract = benchmark_contract.new
    warmup_iterations.times { contract.call(input) }
    GC.start
    before = GC.stat
    elapsed = Benchmark.realtime { iterations.times { contract.call(input) } }
    after = GC.stat

    puts JSON.generate(
      "engine" => "dry-validation",
      "version" => Gem.loaded_specs.fetch("dry-validation").version.to_s,
      "ruby" => RUBY_DESCRIPTION,
      "iterations" => iterations,
      "warmup_iterations" => warmup_iterations,
      "elapsed" => elapsed,
      "throughput" => iterations / elapsed,
      "allocated_objects" => after[:total_allocated_objects] - before[:total_allocated_objects]
    )
  RUBY

  env = {}
  ENV.each_key do |key|
    env[key] = nil if key.start_with?('BUNDLE_', 'BUNDLER_') || key == 'RUBYLIB' || key == 'RUBYOPT'
  end

  stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-e', source, chdir: Dir.tmpdir)
  return JSON.parse(stdout) if status.success?

  raise <<~MESSAGE
    upstream dry-validation benchmark failed.
    Install the upstream gem for #{RbConfig.ruby} with `gem install dry-validation`
    if you want ENGINE=upstream or ENGINE=all comparisons.

    #{stderr}
  MESSAGE
end

def requested_results
  case ENGINE
  when 'rust', 'dry-validation-rust'
    [rust_result]
  when 'upstream', 'dry-validation'
    [upstream_result]
  when 'all', 'compare'
    [rust_result, upstream_result]
  else
    abort "Unknown ENGINE=#{ENGINE.inspect}. Use all, rust, or upstream."
  end
end

def print_result(result)
  puts result.fetch('engine')
  puts "  version: #{result.fetch('version')}"
  puts "  ruby: #{result.fetch('ruby')}"
  puts "  iterations: #{result.fetch('iterations')}"
  puts "  warmup: #{result.fetch('warmup_iterations')}"
  puts "  elapsed: #{result.fetch('elapsed').round(4)}s"
  puts "  throughput: #{result.fetch('throughput').round(1)} validations/s"
  puts "  allocated objects: #{result.fetch('allocated_objects')}"
end

results = requested_results
if FORMAT == 'json'
  payload = {
    'benchmark' => 'schema_throughput',
    'ruby_platform' => RUBY_PLATFORM,
    'engines' => results
  }
  if results.size == 2
    rust, upstream = results
    payload['comparison'] = {
      'throughput_ratio' => rust.fetch('throughput') / upstream.fetch('throughput'),
      'allocation_ratio' => rust.fetch('allocated_objects').to_f / upstream.fetch('allocated_objects')
    }
  end
  puts JSON.pretty_generate(payload)
elsif FORMAT == 'text'
  results.each_with_index do |result, index|
    puts if index.positive?
    print_result(result)
  end

  if results.size == 2
    rust, upstream = results
    puts
    puts 'comparison'
    puts "  throughput ratio: #{(rust.fetch('throughput') / upstream.fetch('throughput')).round(2)}x"
    puts "  allocation ratio: #{(rust.fetch('allocated_objects').to_f / upstream.fetch('allocated_objects')).round(2)}x"
  end
else
  abort "Unknown FORMAT=#{FORMAT.inspect}. Use text or json."
end
