# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'rbconfig'

class FuzzEngineTest < Minitest::Test
  UPSTREAM_VERSION = '1.11.1'
  ITERATIONS = 1_000
  HOSTILE_INPUT_ITERATIONS = 192
  HOSTILE_INPUT_SEED = 91_337

  RUNNER = <<~RUBY
    require 'json'

    mode = ARGV.fetch(0)
    payloads = JSON.parse(STDIN.read)
    if mode == 'upstream'
      project_lib = File.join(ENV.fetch('DRY_VALIDATION_RUST_PROJECT_ROOT'), 'lib')
      $LOAD_PATH.delete_if { |entry| File.expand_path(entry) == project_lib }
      gem 'dry-validation', ENV.fetch('DRY_VALIDATION_UPSTREAM_VERSION')
      require 'dry/validation'
    else
      require 'dry/validation'
    end

    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key.to_s] = normalize(child) }
      when Array then value.map { |child| normalize(child) }
      when Symbol then { '__symbol__' => value.to_s }
      else value
      end
    end

    payloads.map do |payload|
      begin
        contract = eval(payload.fetch('source'), binding, 'fuzz-case.rb', 1)
        result = contract.new.call(payload.fetch('input'))
        {
          'success' => result.success?,
          'output' => normalize(result.to_h),
          'errors' => normalize(result.errors.to_h)
        }
      rescue StandardError => error
        { 'exception' => { 'class' => error.class.name, 'message' => error.message } }
      end
    end.then { |results| puts JSON.generate(results) }
  RUBY

  def test_seeded_hostile_hash_corpus_does_not_crash_the_ruby_process
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, '-Ilib', '-e', hostile_input_script,
      chdir: PROJECT_ROOT
    )

    assert status.success?, <<~MESSAGE
      Engine fuzz subprocess exited with #{status.inspect}.
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE
  end

  def test_generated_supported_schemas_match_pinned_upstream
    seed = ENV.fetch('FUZZ_SEED') { Random.new_seed }
    seed = Integer(seed)
    cases = generate_cases(seed)

    upstream_results = run_cases('upstream', cases)
    rust_results = run_cases('rust', cases)

    cases.each_with_index do |fuzz_case, index|
      assert_equal upstream_results.fetch(index), rust_results.fetch(index), failure_message(seed, index, fuzz_case)
    end
  end

  private

  def generate_cases(seed)
    random = Random.new(seed)
    Array.new(ITERATIONS) { generate_case(random) }
  end

  def generate_case(random)
    fields = Array.new(random.rand(1..4)) do |index|
      name = "field_#{index}"
      kind = %i[string integer bool].sample(random: random)
      required = random.rand(2).zero?
      [name, kind, required]
    end

    declarations = fields.map do |name, kind, required|
      presence = required ? 'required' : 'optional'
      "#{presence}(:#{name}).value(:#{kind})"
    end
    input = fields.each_with_object({}) do |(name, kind, _required), result|
      next if random.rand(4).zero?

      result[name] = random_input_for(kind, random)
    end
    input['unknown'] = random_value(random) if random.rand(3).zero?

    {
      'source' => "Class.new(Dry::Validation::Contract) { params { #{declarations.join('; ')} } }",
      'input' => input
    }
  end

  def random_input_for(kind, random)
    valid_values = {
      string: ['text', '', '42'],
      integer: [-1, 0, 1, '42'],
      bool: [true, false, 'true', 'false']
    }
    invalid_values = {
      string: [nil, [], {}, 0],
      integer: [nil, [], {}, 'not-a-number'],
      bool: [nil, [], {}, 'not-a-boolean']
    }.fetch(kind)
    values = random.rand(3).zero? ? invalid_values : valid_values.fetch(kind)
    values.sample(random: random)
  end

  def random_value(random)
    [nil, true, false, 0, 'value', [], {}].sample(random: random)
  end

  def run_cases(mode, cases)
    command = if mode == 'upstream'
                [RbConfig.ruby, '-rbundler/setup', '-e', RUNNER, mode]
              else
                [RbConfig.ruby, "-I#{File.join(PROJECT_ROOT, 'lib')}", '-e', RUNNER, mode]
              end
    environment = {
      'DRY_VALIDATION_RUST_PROJECT_ROOT' => PROJECT_ROOT,
      'DRY_VALIDATION_UPSTREAM_VERSION' => UPSTREAM_VERSION
    }
    stdout, stderr, status = Bundler.with_unbundled_env do
      Open3.capture3(environment, *command, stdin_data: JSON.generate(cases))
    end

    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def failure_message(seed, index, fuzz_case)
    <<~MESSAGE
      Fuzz mismatch at case #{index} with seed #{seed}.
      Reproduce with: FUZZ_SEED=#{seed} bundle exec ruby -Itest test/fuzz_engine_test.rb
      Case: #{JSON.generate(fuzz_case)}
    MESSAGE
  end

  def hostile_input_script
    <<~RUBY
      require 'dry/validation/rust'

      class ExplosiveKey
        def to_s
          raise 'unexpected keys may reject hostile #to_s implementations'
        end
      end

      contract = Class.new(Dry::Validation::Rust::Contract) do
        config.validate_keys = true

        params do
          required(:profile).hash do
            optional(:details).hash { optional(:name).value(:string) }
          end
          optional(:items).array(:hash) { optional(:id).value(:integer) }
          optional(:enabled).value(:bool)
        end
      end.new

      def random_value(random, depth)
        values = [nil, true, false, -1, 0, 1, 1.5, '', '42', :symbol, Object.new, /value/]
        return values.fetch(random.rand(values.length)) if depth.zero?

        case random.rand(4)
        when 0 then values.fetch(random.rand(values.length))
        when 1 then Array.new(random.rand(4)) { random_value(random, depth - 1) }
        when 2
          Array.new(random.rand(4)).each_with_index.with_object({}) do |(_, index), hash|
            hash[index.even? ? :value : 'value'] = random_value(random, depth - 1)
          end
        else Object.new
        end
      end

      def deeply_nested_hash
        300.times.reduce({ leaf: 'value' }) { |value| { nested: value } }
      end

      def cyclic_hash
        hash = { details: { name: 'Ada' } }
        hash[:cycle] = hash
        hash
      end

      def cyclic_array
        array = []
        array << array
        array
      end

      def default_proc_hash
        Hash.new do |_hash, _key|
          raise 'native lookup must not turn a missing key into a crash'
        end
      end

      inputs = [
        { profile: cyclic_hash },
        { profile: { details: deeply_nested_hash } },
        { profile: { details: cyclic_hash }, items: cyclic_array },
        { profile: default_proc_hash, ExplosiveKey.new => Object.new }
      ]
      random = Random.new(#{HOSTILE_INPUT_SEED})
      #{HOSTILE_INPUT_ITERATIONS}.times do
        input = {
          profile: random_value(random, 5),
          items: random_value(random, 5),
          enabled: random_value(random, 2)
        }
        input[ExplosiveKey.new] = random_value(random, 3) if random.rand(4).zero?
        inputs << input
      end

      inputs.each do |input|
        contract.call(input)
      rescue StandardError
        # Validation failures and Ruby callback errors are permitted. A native
        # crash, abort, or unwound Magnus exception terminates this subprocess.
      end
    RUBY
  end
end
