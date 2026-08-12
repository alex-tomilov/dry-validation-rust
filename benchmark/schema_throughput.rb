# frozen_string_literal: true

require 'benchmark'
require 'json'
require 'open3'
require 'rbconfig'

ITERATIONS = Integer(ENV.fetch('N', '10000'))
WARMUP_ITERATIONS = Integer(ENV.fetch('WARMUP', '1000'))
LATENCY_SAMPLES = Integer(ENV.fetch('LATENCY_SAMPLES', '200'))
ENGINE = ENV.fetch('ENGINE', 'all')
FORMAT = ENV.fetch('FORMAT', 'text')
SCENARIO_FILTER = ENV.fetch('SCENARIO', nil)
VALIDATE_KEYS = ENV.fetch('VALIDATE_KEYS', 'false') == 'true'
PROJECT_LIB = File.expand_path('../lib', __dir__)

def flat_schema(field_count)
  (0...field_count).map do |index|
    "required(:field_#{index}).value(:integer, gt?: 0)"
  end.join("\n")
end

def flat_payload(field_count, invalid: false)
  (0...field_count).to_h do |index|
    ["field_#{index}", invalid ? 'invalid' : (index + 1).to_s]
  end
end

def nested_schema(depth)
  openings = (0...depth).map { |index| "required(:level_#{index}).hash do" }
  (openings + ['required(:value).value(:integer, gt?: 0)'] + Array.new(depth, 'end')).join("\n")
end

def nested_payload(depth)
  (depth - 1).downto(0).reduce({ 'value' => '1' }) do |payload, index|
    { "level_#{index}" => payload }
  end
end

def array_payload(invalid: false)
  items = Array.new(100) do |index|
    {
      'id' => invalid && index.zero? ? 'invalid' : (index + 1).to_s,
      'name' => invalid && index.zero? ? '' : "person-#{index}",
      'age' => invalid && index.zero? ? 'invalid' : '30',
      'active' => 'true',
      'role' => 'member'
    }
  end
  { 'items' => items }
end

SCENARIOS = [
  {
    'name' => 'small_form',
    'description' => '5-field web request baseline; all calls valid',
    'source' => flat_schema(5),
    'payloads' => [flat_payload(5)]
  },
  {
    'name' => 'medium_form',
    'description' => '25-field API payload; 80% of calls valid',
    'source' => flat_schema(25),
    'payloads' => Array.new(4, flat_payload(25)) + [flat_payload(25, invalid: true)]
  },
  {
    'name' => 'large_form',
    'description' => '100-field stress case; 50% of calls valid',
    'source' => flat_schema(100),
    'payloads' => [flat_payload(100), flat_payload(100, invalid: true)]
  },
  {
    'name' => 'nested_object',
    'description' => '10-level object traversal; all calls valid',
    'source' => nested_schema(10),
    'payloads' => [nested_payload(10)]
  },
  {
    'name' => 'array_of_objects',
    'description' => '100 objects with 5 fields each; 90% of calls valid',
    'source' => <<~RUBY,
      required(:items).array(:hash) do
        required(:id).value(:integer, gt?: 0)
        required(:name).filled(:string)
        required(:age).value(:integer, gteq?: 18)
        required(:active).value(:bool)
        required(:role).filled(:string)
      end
    RUBY
    'payloads' => Array.new(9, array_payload) + [array_payload(invalid: true)]
  },
  {
    'name' => 'all_invalid',
    'description' => '20 fields with every value invalid; error-path allocation case',
    'source' => flat_schema(20),
    'payloads' => [flat_payload(20, invalid: true)]
  }
].freeze

def selected_scenarios
  return SCENARIOS unless SCENARIO_FILTER

  scenarios = SCENARIOS.select { |scenario| scenario.fetch('name') == SCENARIO_FILTER }
  if scenarios.empty?
    names = SCENARIOS.map { |scenario| scenario.fetch('name') }.join(', ')
    abort "Unknown SCENARIO=#{SCENARIO_FILTER.inspect}. Use one of: #{names}"
  end

  scenarios
end

def percentile(samples, percentile)
  index = ((samples.length - 1) * percentile).ceil
  samples.sort.fetch(index)
end

def rss_kb
  status = '/proc/self/status'
  return Regexp.last_match(1).to_i if File.file?(status) && File.read(status) =~ /^VmHWM:\s+(\d+) kB$/

  output, = Open3.capture2('ps', '-o', 'rss=', '-p', Process.pid.to_s)
  Integer(output.strip)
rescue Errno::ENOENT, ArgumentError
  nil
end

def measure(contract, payloads)
  payload_index = 0
  invoke = lambda do
    payload = payloads.fetch(payload_index % payloads.length)
    payload_index += 1
    contract.call(payload)
  end

  WARMUP_ITERATIONS.times { invoke.call }
  GC.start
  before = GC.stat
  elapsed = Benchmark.realtime { ITERATIONS.times { invoke.call } }
  after = GC.stat

  samples = Array.new([LATENCY_SAMPLES, ITERATIONS].min) do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    invoke.call
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000_000
  end

  {
    'iterations' => ITERATIONS,
    'warmup_iterations' => WARMUP_ITERATIONS,
    'latency_samples' => samples.length,
    'elapsed_seconds' => elapsed,
    'throughput_per_second' => ITERATIONS / elapsed,
    'latency_us' => {
      'p50' => percentile(samples, 0.50),
      'p95' => percentile(samples, 0.95),
      'p99' => percentile(samples, 0.99)
    },
    'ruby_allocated_objects_per_call' => (after[:total_allocated_objects] - before[:total_allocated_objects]).fdiv(ITERATIONS),
    'peak_rss_kb' => rss_kb
  }
end

def benchmark_engine(contract_class, engine:, version:)
  selected_scenarios.map do |scenario|
    configuration = "config.validate_keys = true\n" if VALIDATE_KEYS
    definition = "Class.new(#{contract_class}) do\n#{configuration}params do\n#{scenario.fetch('source')}\nend\nend"
    contract = eval(definition, TOPLEVEL_BINDING, __FILE__, __LINE__).new # rubocop:disable Security/Eval
    measure(contract, scenario.fetch('payloads')).merge(
      'scenario' => scenario.fetch('name'),
      'description' => scenario.fetch('description'),
      'engine' => engine,
      'version' => version,
      'ruby' => RUBY_DESCRIPTION
    )
  end
end

def rust_results
  require 'dry/validation/rust'

  benchmark_engine(
    'Dry::Validation::Rust::Contract',
    engine: 'dry-validation-rust',
    version: Dry::Validation::Rust::VERSION
  )
end

def upstream_results
  source = <<~RUBY
    $LOAD_PATH.delete_if do |path|
      begin
        #{[PROJECT_LIB, File.realpath(PROJECT_LIB)].uniq.inspect}.include?(File.realpath(path))
      rescue Errno::ENOENT
        false
      end
    end
    gem 'dry-validation'
    spec = Gem.loaded_specs.fetch('dry-validation')
    $LOAD_PATH.unshift(File.join(spec.full_gem_path, 'lib'))
    require 'dry/validation'
    load #{__FILE__.inspect}
    puts JSON.generate(benchmark_engine('Dry::Validation::Contract', engine: 'dry-validation', version: spec.version.to_s))
  RUBY
  env = ENV.to_h.reject { |key, _| key.start_with?('BUNDLE_', 'BUNDLER_') || %w[RUBYLIB RUBYOPT ENGINE FORMAT].include?(key) }
  stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-rjson', '-e', source)
  return JSON.parse(stdout) if status.success?

  raise "upstream dry-validation benchmark failed. Install it for #{RbConfig.ruby} before running ENGINE=all or ENGINE=upstream.\n\n#{stderr}"
end

def requested_results
  case ENGINE
  when 'rust', 'dry-validation-rust' then rust_results
  when 'upstream', 'dry-validation' then upstream_results
  when 'all', 'compare' then rust_results + upstream_results
  else abort "Unknown ENGINE=#{ENGINE.inspect}. Use all, rust, or upstream."
  end
end

def environment
  {
    'ruby_platform' => RUBY_PLATFORM,
    'ruby' => RUBY_DESCRIPTION,
    'iterations' => ITERATIONS,
    'warmup_iterations' => WARMUP_ITERATIONS,
    'latency_samples' => LATENCY_SAMPLES,
    'scenario_filter' => SCENARIO_FILTER
  }
end

def print_result(result)
  puts "#{result.fetch('scenario')} (#{result.fetch('engine')})"
  puts "  #{result.fetch('description')}"
  puts "  throughput: #{result.fetch('throughput_per_second').round(1)} validations/s"
  latency = result.fetch('latency_us')
  puts "  latency: p50 #{latency.fetch('p50').round(1)}µs, p95 #{latency.fetch('p95').round(1)}µs, p99 #{latency.fetch('p99').round(1)}µs"
  puts "  Ruby allocations/call: #{result.fetch('ruby_allocated_objects_per_call').round(2)}"
  puts "  peak RSS: #{result.fetch('peak_rss_kb') || 'unavailable'} kB"
end

if __FILE__ == $PROGRAM_NAME
  results = requested_results
  payload = { 'benchmark' => 'schema_throughput_matrix', 'environment' => environment, 'results' => results }

  if FORMAT == 'json'
    puts JSON.pretty_generate(payload)
  elsif FORMAT == 'text'
    results.each_with_index do |result, index|
      puts if index.positive?
      print_result(result)
    end
  else
    abort "Unknown FORMAT=#{FORMAT.inspect}. Use text or json."
  end
end
