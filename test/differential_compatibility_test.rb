# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'

class DifferentialCompatibilityTest < Minitest::Test
  UPSTREAM_VERSION = '1.11.1'

  RUNNER = <<~RUBY
    require "json"

    mode, encoded = ARGV
    payload = JSON.parse(encoded)
    if mode == "upstream"
      project_lib = File.join(ENV.fetch("DRY_VALIDATION_RUST_PROJECT_ROOT"), "lib")
      $LOAD_PATH.delete_if { |entry| File.expand_path(entry) == project_lib }
      gem "dry-validation", ENV.fetch("DRY_VALIDATION_UPSTREAM_VERSION")
    end
    require "dry/validation"
    dry_validation_source = $LOADED_FEATURES.find { |feature| feature.end_with?("/dry/validation.rb") }

    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key.nil? ? "__base__" : key.to_s] = normalize(child) }
      when Array then value.map { |child| normalize(child) }
      when Symbol then { "__symbol__" => value.to_s }
      when Float
        return { "__float__" => "NaN" } if value.nan?
        return { "__float__" => value.infinite? == 1 ? "Infinity" : "-Infinity" } if value.infinite?

        value
      else value
      end
    end

    def classes(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key.nil? ? "__base__" : key.to_s] = classes(child) }
      when Array then value.map { |child| classes(child) }
      else value.class.name
      end
    end

    begin
      trace = []
      contract = eval(payload.fetch("source"), binding, "differential-case.rb", 1)
      options = payload.fetch("options", {}).transform_keys(&:to_sym)
      context = payload.fetch("context", {}).transform_keys(&:to_sym)
      input = if payload.key?("input_source")
                eval(payload.fetch("input_source"), binding, "differential-input.rb", 1)
              else
                payload.fetch("input")
              end
      result = contract.new(**options).call(input, context)
      puts JSON.generate(
        "engine" => mode,
        "dry_validation_version" => Gem.loaded_specs["dry-validation"]&.version&.to_s,
        "dry_validation_source" => dry_validation_source,
        "success" => result.success?,
        "output" => normalize(result.to_h),
        "classes" => classes(result.to_h),
        "errors" => normalize(result.errors.to_h),
        "context" => normalize(result.context.each_pair.to_h),
        "trace" => trace
      )
    rescue StandardError => error
      puts JSON.generate(
        "engine" => mode,
        "dry_validation_version" => Gem.loaded_specs["dry-validation"]&.version&.to_s,
        "exception" => { "class" => error.class.name, "message" => error.message }
      )
    end
  RUBY

  def test_schema_and_rule_subset_matches_pinned_upstream_in_isolated_processes
    differential_cases.each do |fixture|
      upstream = run_case('upstream', fixture)
      rust = run_case('rust', fixture)

      assert_equal UPSTREAM_VERSION, upstream.fetch('dry_validation_version'), fixture.fetch(:name)
      assert_nil rust.fetch('dry_validation_version'), fixture.fetch(:name)

      if upstream['exception'] || rust['exception']
        assert_equal upstream['exception'], rust['exception'], fixture.fetch(:name)
        next
      end

      assert_equal upstream_validation_source, upstream.fetch('dry_validation_source'), fixture.fetch(:name)
      assert_equal comparable_payload(upstream), comparable_payload(rust), fixture.fetch(:name)
    end
  end

  def test_recognized_unsupported_constructs_fail_explicitly_and_deterministically
    unsupported_cases.each do |fixture|
      first = run_rust_source(fixture.fetch(:source), fixture.fetch(:input, {}))
      second = run_rust_source(fixture.fetch(:source), fixture.fetch(:input, {}))

      assert_equal first, second, fixture.fetch(:name)
      exception = first.fetch('exception')
      assert_equal 'Dry::Validation::Rust::UnsupportedFeatureError', exception.fetch('class'), fixture.fetch(:name)
      assert_match fixture.fetch(:message), exception.fetch('message'), fixture.fetch(:name)
    end
  end

  private

  def run_case(mode, fixture)
    capture = mode == 'upstream' ? :capture_bundled : :capture_isolated
    payload = {
      'source' => fixture.fetch(:source),
      'options' => fixture.fetch(:options, {}),
      'context' => fixture.fetch(:context, {})
    }
    payload['input'] = fixture.fetch(:input) if fixture.key?(:input)
    payload['input_source'] = fixture.fetch(:input_source) if fixture.key?(:input_source)
    stdout, stderr, status = send(
      capture,
      {
        'DRY_VALIDATION_RUST_PROJECT_ROOT' => PROJECT_ROOT,
        'DRY_VALIDATION_UPSTREAM_VERSION' => UPSTREAM_VERSION
      },
      RbConfig.ruby, *ruby_load_path(mode), '-e', RUNNER, mode,
      JSON.generate(payload)
    )
    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def run_rust_source(source, input = {})
    stdout, stderr, status = capture_isolated(
      {}, RbConfig.ruby, *ruby_load_path('rust'), '-e', RUNNER, 'rust',
      JSON.generate('source' => source, 'input' => input)
    )
    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def ruby_load_path(mode)
    return ['-rbundler/setup'] if mode == 'upstream'

    ["-I#{File.join(PROJECT_ROOT, 'lib')}"]
  end

  def capture_isolated(environment, *command)
    Bundler.with_unbundled_env { Open3.capture3(environment, *command) }
  end

  def capture_bundled(environment, *command)
    Open3.capture3(environment, *command)
  end

  def comparable_payload(payload)
    payload.except('engine', 'dry_validation_version', 'dry_validation_source')
  end

  def upstream_validation_source
    File.join(
      Gem::Specification.find_by_name('dry-validation', UPSTREAM_VERSION).full_gem_path,
      'lib/dry/validation.rb'
    )
  end

  def differential_cases
    [
      schema_case('required scalar succeeds', 'params { required(:name).value(:string) }', { 'name' => 'Jane' }),
      schema_case('required scalar missing', 'params { required(:name).value(:string) }', {}),
      schema_case('optional scalar omitted', 'params { optional(:name).value(:string) }', {}),
      schema_case('optional scalar supplied', 'params { optional(:name).value(:string) }', { 'name' => 'Jane' }),
      *presence_semantics_cases,
      *key_mode_cases,
      schema_case('integer coercion', 'params { required(:age).value(:integer) }', { 'age' => '42' }),
      schema_case('integer coercion failure', 'params { required(:age).value(:integer) }', { 'age' => 'forty-two' }),
      *scalar_coercion_boundary_cases,
      schema_case('boolean coercion', 'params { required(:enabled).value(:bool) }', { 'enabled' => 'false' }),
      schema_case('boolean true coercion', 'params { required(:enabled).value(:bool) }', { 'enabled' => 'true' }),
      schema_case('float coercion', 'params { required(:ratio).value(:float) }', { 'ratio' => '1.5' }),
      schema_case('decimal coercion', 'params { required(:amount).value(:decimal) }', { 'amount' => '12.50' }),
      schema_case('symbol coercion', 'params { required(:role).value(:symbol) }', { 'role' => 'admin' }),
      schema_case('date coercion', 'params { required(:birthday).value(:date) }', { 'birthday' => '2026-07-12' }),
      schema_case('date time coercion', 'params { required(:created_at).value(:date_time) }',
                  { 'created_at' => '2026-07-12T10:00:00+00:00' }),
      schema_case('time coercion', 'params { required(:created_at).value(:time) }',
                  { 'created_at' => '2026-07-12T10:00:00Z' }),
      schema_case('filled rejects blank string', 'params { required(:name).filled(:string) }', { 'name' => '' }),
      schema_case('filled preserves companion size predicate',
                  'params { required(:name).filled(:string, min_size?: 3) }', { 'name' => '' }),
      schema_case('maybe converts blank params string', 'params { required(:name).maybe(:string) }', { 'name' => '' }),
      schema_case('nested hash succeeds', 'params { required(:profile).hash { required(:age).value(:integer) } }',
                  { 'profile' => { 'age' => '42' } }),
      schema_case('nested hash missing key', 'params { required(:profile).hash { required(:age).value(:integer) } }',
                  { 'profile' => {} }),
      *nested_hash_cases,
      schema_case('primitive array succeeds', 'params { required(:scores).array(:integer) }',
                  { 'scores' => %w[1 2] }),
      schema_case('primitive array coercion failure', 'params { required(:scores).array(:integer) }',
                  { 'scores' => %w[1 bad] }),
      schema_case('array of hashes succeeds',
                  'params { required(:people).array(:hash) { required(:id).value(:integer) } }', { 'people' => [{ 'id' => '7' }] }),
      schema_case('array of hashes invalid',
                  'params { required(:people).array(:hash) { required(:id).value(:integer) } }', { 'people' => [{ 'id' => 'bad' }] }),
      *array_cases,
      schema_case('greater than predicate', 'params { required(:age).value(:integer, gt?: 18) }', { 'age' => '18' }),
      schema_case('greater than or equal predicate', 'params { required(:age).value(:integer, gteq?: 18) }',
                  { 'age' => '18' }),
      schema_case('less than predicate', 'params { required(:age).value(:integer, lt?: 18) }', { 'age' => '18' }),
      schema_case('less than or equal predicate', 'params { required(:age).value(:integer, lteq?: 18) }',
                  { 'age' => '18' }),
      schema_case('exact size predicate', 'params { required(:code).value(:string, size?: 3) }', { 'code' => 'AB' }),
      schema_case('minimum size predicate', 'params { required(:name).value(:string, min_size?: 3) }',
                  { 'name' => 'Al' }),
      schema_case('maximum size predicate', 'params { required(:name).value(:string, max_size?: 3) }',
                  { 'name' => 'Alex' }),
      schema_case('odd predicate', 'params { required(:number).value(:integer, :odd?) }', { 'number' => '2' }),
      schema_case('even predicate', 'params { required(:number).value(:integer, :even?) }', { 'number' => '3' }),
      schema_case('format predicate', 'params { required(:email).value(:string, format?: /\\A[^@]+@[^@]+\\z/) }',
                  { 'email' => 'invalid' }),
      schema_case('included in predicate', 'params { required(:role).value(:string, included_in?: %w[admin user]) }',
                  { 'role' => 'guest' }),
      schema_case('excluded from predicate',
                  'params { required(:role).value(:string, excluded_from?: %w[root admin]) }', { 'role' => 'root' }),
      schema_case('equality predicate', 'params { required(:role).value(:string, eql?: "admin") }',
                  { 'role' => 'user' }),
      schema_case('inequality predicate', 'params { required(:role).value(:string, not_eql?: "admin") }',
                  { 'role' => 'admin' }),
      schema_case('json does not coerce', 'json { required(:age).value(:integer) }', { 'age' => '42' }),
      schema_case('schema retains symbol keys', 'schema { required(:age).value(:integer) }', { age: 42 }),
      rule_case('single key rule',
                'params { required(:age).value(:integer) }; rule(:age) { key.failure("must be adult") if value < 18 }', { 'age' => '17' }),
      rule_case('multi key rule',
                'params { required(:start).value(:integer); required(:finish).value(:integer) }; rule(:start, :finish) { key(:finish).failure("must follow start") if values[:finish] < values[:start] }', { 'start' => '5', 'finish' => '4' }),
      rule_case('base rule failure',
                'params { required(:age).value(:integer) }; rule(:age) { base.failure("blocked") if value == 0 }', { 'age' => '0' }),
      rule_case('dot string nested rule path',
                'params { required(:address).hash { required(:city).filled(:string) } }; rule("address.city") { key.failure("is unavailable") if value == "Nowhere" }', { 'address' => { 'city' => 'Nowhere' } }),
      rule_case('array nested rule path',
                'params { required(:address).hash { required(:city).filled(:string) } }; rule([:address, :city]) { key.failure("is unavailable") if value == "Nowhere" }', { 'address' => { 'city' => 'Nowhere' } }),
      rule_case('simple hash nested rule path',
                'params { required(:address).hash { required(:city).filled(:string) } }; rule(address: :city) { key.failure("is unavailable") if value == "Nowhere" }', { 'address' => { 'city' => 'Nowhere' } }),
      rule_case('multi hash nested rule path',
                'params { required(:address).hash { required(:city).filled(:string); required(:zip).filled(:string) } }; rule(address: [:city, :zip]) { key.failure("is unavailable") if values[:address][:city] == "Nowhere" && values[:address][:zip] == "00000" }', { 'address' => { 'city' => 'Nowhere', 'zip' => '00000' } }),
      rule_case('rule skips after schema failure',
                'params { required(:age).value(:integer) }; rule(:age) { trace << "ran"; key.failure("must be adult") if value < 18 }', { 'age' => 'bad' }),
      rule_case('rule trace on valid schema',
                'params { required(:age).value(:integer) }; rule(:age) { trace << "ran"; key.failure("must be adult") if value < 18 }', { 'age' => '17' }),
      rule_case('array rule skips invalid members',
                'params { required(:numbers).array(:integer) }; rule(:numbers).each { key.failure("must be positive") if value <= 0 }', { 'numbers' => %w[bad 0 1] }),
      rule_case('optional key rule executes when key is absent',
                'params { optional(:age).value(:integer) }; rule(:age) { key.failure("must be supplied") unless key? }', {}),
      rule_case('rule exception propagates',
                'params { required(:age).value(:integer) }; rule(:age) { raise ArgumentError, "rule exploded" }', { 'age' => '17' }),
      contract_case(
        'required option and mutable call context',
        'option :minimum; params { required(:age).value(:integer) }; rule(:age) { |context:| context[:minimum] = minimum; key.failure("must meet minimum") if value < minimum }',
        { 'age' => '17' },
        options: { minimum: 18 },
        context: { request_id: 7 }
      ),
      contract_case(
        'global macro failure',
        'Dry::Validation.register_macro(:differential_even) { key.failure("must be even") unless value.even? }; params { required(:number).value(:integer) }; rule(:number).validate(:differential_even)',
        { 'number' => '3' }
      ),
      source_case(
        'inherited contract schema rules and macros',
        'parent = Class.new(Dry::Validation::Contract) do; register_macro(:minimum) { |macro:| key.failure("must meet minimum") if value < macro.args.fetch(0) }; params { required(:name).filled(:string) }; rule(:name) { key.failure("is blocked") if value == "blocked" }; end; Class.new(parent) do; params { required(:age).value(:integer) }; rule(:age).validate(minimum: 18); end',
        { 'name' => 'blocked', 'age' => '17' }
      ),
      contract_case(
        'imported reusable schema',
        'address = Dry::Schema.Params { required(:city).filled(:string) }; params(address) { required(:name).filled(:string) }',
        { 'city' => '', 'name' => 'Jane' }
      )
    ]
  end

  def unsupported_cases
    [
      { name: 'unsupported type object',
        source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(Object.new) } }', message: /unsupported type or predicate specification: Object/ },
      { name: 'unknown predicate',
        source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(:integer, unknown?: 1) } }', input: { 'age' => '1' }, message: /predicate :unknown/ },
      { name: 'predicate composition',
        source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(:integer) { gt? 18 } } }', message: /predicate composition/ },
      { name: 'schema before processor hook',
        source: 'Class.new(Dry::Validation::Contract) { params { before(:value_coercer) { |input| input } } }', message: /schema before processor hooks/ },
      { name: 'schema after processor hook', source: 'Class.new(Dry::Validation::Contract) { params { after(:value_coercer) { |input| input } } }', message: /schema after processor hooks/ }
    ]
  end

  def presence_semantics_cases
    [
      schema_case('required value rejects nil', 'params { required(:name).value(:string) }', { 'name' => nil }),
      schema_case('required filled rejects nil', 'params { required(:name).filled(:string) }', { 'name' => nil }),
      schema_case('required maybe accepts nil', 'params { required(:name).maybe(:string) }', { 'name' => nil }),
      schema_case('optional value rejects supplied nil', 'params { optional(:name).value(:string) }',
                  { 'name' => nil }),
      schema_case('optional filled rejects supplied nil', 'params { optional(:name).filled(:string) }',
                  { 'name' => nil }),
      schema_case('optional maybe accepts nil', 'params { optional(:name).maybe(:string) }', { 'name' => nil }),
      schema_case('params value retains empty string', 'params { required(:name).value(:string) }', { 'name' => '' }),
      schema_case('params filled rejects empty string', 'params { required(:name).filled(:string) }', { 'name' => '' }),
      schema_case('params maybe converts empty string to nil', 'params { required(:name).maybe(:string) }',
                  { 'name' => '' }),
      schema_case('params filled rejects empty array', 'params { required(:tags).filled(:array) }', { 'tags' => [] }),
      schema_case('params filled rejects empty hash', 'params { required(:metadata).filled(:hash) }',
                  { 'metadata' => {} }),
      schema_case('json value rejects nil', 'json { required(:name).value(:string) }', { 'name' => nil }),
      schema_case('json filled rejects nil', 'json { required(:name).filled(:string) }', { 'name' => nil }),
      schema_case('json maybe accepts nil', 'json { required(:name).maybe(:string) }', { 'name' => nil }),
      schema_case('json filled rejects empty string', 'json { required(:name).filled(:string) }', { 'name' => '' }),
      schema_case('json maybe retains empty string', 'json { required(:name).maybe(:string) }', { 'name' => '' }),
      schema_case('schema required key is missing for string input', 'schema { required(:name).value(:string) }', {}),
      schema_case('schema optional key is omitted for string input', 'schema { optional(:name).value(:string) }', {})
    ]
  end

  def key_mode_cases
    declaration = 'required(:profile).hash { required(:name).value(:string) }; required(:age).value(:integer)'
    mixed_keys = '{ "profile" => { name: "Jane", "ignored" => "value" }, age: 21, "ignored" => true }'

    [
      source_case(
        'params accepts mixed nested keys and filters undeclared keys',
        "Class.new(Dry::Validation::Contract) do\nparams { #{declaration} }\nend",
        input_source: mixed_keys
      ),
      source_case(
        'json accepts mixed nested keys and filters undeclared keys',
        "Class.new(Dry::Validation::Contract) do\njson { #{declaration} }\nend",
        input_source: mixed_keys
      ),
      source_case(
        'schema requires symbol keys and filters undeclared keys',
        "Class.new(Dry::Validation::Contract) do\nschema { #{declaration} }\nend",
        input_source: mixed_keys
      ),
      source_case(
        'schema requires nested symbol keys',
        "Class.new(Dry::Validation::Contract) do\nschema { required(:profile).hash { required(:name).value(:string) } }\nend",
        input_source: '{ profile: { "name" => "Jane" } }'
      ),
      source_case(
        'params rejects unknown keys when configured',
        <<~RUBY,
          Class.new(Dry::Validation::Contract) do
            config.validate_keys = true
            params { required(:name).value(:string) }
          end
        RUBY
        { 'name' => 'Jane', 'unexpected' => true }
      )
    ]
  end

  def nested_hash_cases
    declaration = <<~RUBY.strip
      params do
        required(:account).hash do
          required(:profile).hash do
            required(:age).value(:integer)
            optional(:nickname).maybe(:string)
          end
          optional(:settings).hash { optional(:timezone).value(:string) }
        end
      end
    RUBY

    [
      schema_case(
        'multilevel nested hash coerces and filters keys',
        declaration,
        { 'account' => { 'profile' => { 'age' => '42', 'ignored' => true },
                         'settings' => { 'timezone' => 'UTC', 'ignored' => true }, 'ignored' => true } }
      ),
      schema_case('nested hash missing parent', declaration, { 'account' => {} }),
      schema_case('nested hash rejects invalid parent', declaration, { 'account' => { 'profile' => 'not a hash' } }),
      source_case(
        'nested hash accepts frozen input',
        "Class.new(Dry::Validation::Contract) do\n#{declaration}\nend",
        input_source: '{ "account" => { "profile" => { "age" => "42", "ignored" => true }, "ignored" => true }.freeze, "ignored" => true }.freeze'
      )
    ]
  end

  def scalar_coercion_boundary_cases
    [
      schema_case('integer accepts arbitrary precision', 'params { required(:value).value(:integer) }',
                  { 'value' => '9223372036854775808' }),
      schema_case('integer accepts underscores and signs', 'params { required(:value).value(:integer) }',
                  { 'value' => '+1_024' }),
      schema_case('integer rejects decimal syntax', 'params { required(:value).value(:integer) }',
                  { 'value' => '12.0' }),
      schema_case('boolean accepts y', 'params { required(:value).value(:bool) }', { 'value' => 'Y' }),
      schema_case('boolean accepts n', 'params { required(:value).value(:bool) }', { 'value' => 'n' }),
      schema_case('boolean rejects unknown spelling', 'params { required(:value).value(:bool) }',
                  { 'value' => 'maybe' }),
      schema_case('true coerces boolean input', 'params { required(:value).value(:true) }', { 'value' => 'yes' }),
      schema_case('true reports coerced false input', 'params { required(:value).value(:true) }', { 'value' => 'no' }),
      schema_case('false coerces boolean input', 'params { required(:value).value(:false) }', { 'value' => 'n' }),
      schema_case('false reports coerced true input', 'params { required(:value).value(:false) }', { 'value' => 'y' }),
      schema_case('float accepts underscore separators', 'params { required(:value).value(:float) }',
                  { 'value' => '1_2' }),
      schema_case('float permits numeric overflow', 'params { required(:value).value(:float) }',
                  { 'value' => '1e999' }),
      schema_case('float rejects literal infinity', 'params { required(:value).value(:float) }',
                  { 'value' => 'Infinity' }),
      schema_case('float rejects abbreviated infinity', 'params { required(:value).value(:float) }',
                  { 'value' => 'Inf' }),
      schema_case('float rejects literal nan', 'params { required(:value).value(:float) }', { 'value' => 'NaN' }),
      schema_case('decimal accepts underscore separators', 'params { required(:value).value(:decimal) }',
                  { 'value' => '1_2' }),
      schema_case('decimal permits large finite exponents', 'params { required(:value).value(:decimal) }',
                  { 'value' => '1e999' }),
      schema_case('decimal rejects infinity', 'params { required(:value).value(:decimal) }', { 'value' => 'Infinity' }),
      schema_case('decimal rejects nan', 'params { required(:value).value(:decimal) }', { 'value' => 'NaN' }),
      schema_case('date accepts date-time input', 'params { required(:value).value(:date) }',
                  { 'value' => '2026-07-12T10:00:00Z' }),
      schema_case('date rejects invalid calendar date', 'params { required(:value).value(:date) }',
                  { 'value' => '2026-02-30' }),
      schema_case('date time rejects invalid calendar date', 'params { required(:value).value(:date_time) }',
                  { 'value' => '2026-02-30T10:00:00Z' }),
      schema_case('time accepts time-only input', 'params { required(:value).value(:time) }',
                  { 'value' => '10:00:00' }),
      schema_case('symbol accepts empty string', 'params { required(:value).value(:symbol) }', { 'value' => '' })
    ]
  end

  def array_cases
    nested_members = <<~RUBY.strip
      params do
        required(:people).array(:hash) do
          required(:id).value(:integer)
          required(:profile).hash { required(:age).value(:integer) }
        end
      end
    RUBY

    [
      schema_case('array rejects invalid container', 'params { required(:scores).array(:integer) }',
                  { 'scores' => 'not an array' }),
      schema_case('array accepts empty members', 'params { required(:scores).array(:integer) }', { 'scores' => [] }),
      schema_case('array reports multiple primitive member failures', 'params { required(:scores).array(:integer) }',
                  { 'scores' => ['bad', '2', 'also bad'] }),
      schema_case('array hash member rejects non-hash',
                  'params { required(:people).array(:hash) { required(:id).value(:integer) } }', { 'people' => ['not a hash'] }),
      schema_case(
        'array hash members retain stable nested index paths',
        nested_members,
        { 'people' => [{ 'id' => 'bad', 'profile' => { 'age' => 'bad' } }, 'not a hash', { 'profile' => {} }] }
      )
    ]
  end

  def schema_case(name, declaration, input)
    { name: name, source: "Class.new(Dry::Validation::Contract) do\n#{declaration}\nend", input: input }
  end

  def rule_case(name, body, input)
    { name: name, source: "Class.new(Dry::Validation::Contract) do\n#{body}\nend", input: input }
  end

  def contract_case(name, body, input, options: {}, context: {})
    source_case(
      name,
      "Class.new(Dry::Validation::Contract) do\n#{body}\nend",
      input,
      options: options,
      context: context
    )
  end

  def source_case(name, source, input = nil, input_source: nil, options: {}, context: {})
    payload = {
      name: name,
      source: source,
      options: options,
      context: context
    }
    payload[:input] = input unless input.nil?
    payload[:input_source] = input_source if input_source
    payload
  end
end
