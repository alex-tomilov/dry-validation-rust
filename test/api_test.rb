# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'

class ApiTest < Minitest::Test
  CONCURRENCY_THREAD_COUNT = 50
  CONCURRENCY_CALLS_PER_THREAD = 1_000
  SIDE_BY_SIDE_PUBLIC_API = {
    Dry::Validation::Rust::Contract => {
      class: %i[build config import_predicates_as_macros inherited json macro_registry option option_definitions own_rules params register_macro rule rules schema schema_definition],
      instance: %i[[] call default_context inspect macro_registered? resolve_macro]
    },
    Dry::Validation::Rust::Schema => {
      class: %i[JSON Params define],
      instance: %i[[] call engine fields inspect key_paths mode]
    },
    Dry::Validation::Rust::Result => {
      class: [],
      instance: %i[[] add_error base_rule_error? context deconstruct deconstruct_keys error? errors failure? finalize! inspect key? rule_error? schema_error? schema_result success? to_h values]
    },
    Dry::Validation::Rust::MessageSet => {
      class: [],
      instance: %i[[] add each empty? filter freeze messages options to_h with]
    },
    Dry::Validation::Rust::Evaluator => {
      class: [],
      instance: %i[_context base base_rule_error? context contract error? execute failures index key key? key_name paths result rule_error? schema_error? value values]
    },
    Dry::Validation::Rust::Values => {
      class: [],
      instance: %i[[] data deconstruct_keys each fetch key? to_h]
    }
  }.freeze

  def test_side_by_side_public_api_is_locked_for_the_0_1_line
    SIDE_BY_SIDE_PUBLIC_API.each do |klass, expected|
      assert_equal expected.fetch(:class).sort, klass.singleton_methods(false).sort, "#{klass} class API"
      assert_equal expected.fetch(:instance).sort, klass.public_instance_methods(false).sort, "#{klass} instance API"
    end
  end

  def test_native_plan_metadata
    contract = build_contract do
      params do
        required(:name).filled(:string)
        required(:address).hash { required(:city).filled(:string) }
      end
    end

    engine = contract.schema.engine
    assert_equal 3, engine.field_count
    assert_operator engine.plan_bytes, :>, 100
  end

  def test_contract_factory_and_pattern_matching
    contract = Dry::Validation::Rust.Contract do
      params { required(:name).filled(:string) }
    end
    result = contract.call(name: 'Jane')

    matched = case result
              in { name: }
                name
              end
    assert_equal 'Jane', matched
  end

  def test_schema_and_rule_inheritance
    parent = build_contract do
      params { required(:name).filled(:string) }
      rule(:name) { key.failure('is blocked') if value == 'blocked' }
    end
    child = Class.new(parent) do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure('too young') if value < 18 }
    end

    result = child.new.call(name: 'blocked', age: '10')
    assert_equal({ name: ['is blocked'], age: ['too young'] }, result.errors.to_h)
  end

  def test_external_schema_reuse
    address = Dry::Validation::Rust::Schema.Params do
      required(:city).filled(:string)
    end
    contract = build_contract do
      params(address) { required(:name).filled(:string) }
    end

    assert contract.new.call(city: 'Astana', name: 'Alexey').success?
  end

  def test_message_set_memoizes_to_h_and_invalidates_it_when_a_message_is_added
    set = Dry::Validation::Rust::MessageSet.new([Dry::Validation::Rust::Message.new('is invalid', path: :name)])

    first = set.to_h
    assert_same first, set.to_h
    assert_equal({ name: ['is invalid'] }, first)

    set.add(Dry::Validation::Rust::Message.new('is too short', path: :name))

    refute_same first, set.to_h
    assert_equal({ name: ['is invalid', 'is too short'] }, set.to_h)
  end

  def test_frozen_message_set_keeps_a_frozen_cached_hash
    set = Dry::Validation::Rust::MessageSet.new([Dry::Validation::Rust::Message.new('is invalid', path: :name)])

    assert set.freeze.to_h.frozen?
  end

  def test_message_set_exposes_a_frozen_messages_view_and_add_refreshes_it
    set = Dry::Validation::Rust::MessageSet.new([Dry::Validation::Rust::Message.new('is invalid', path: :name)])

    first = set.messages
    assert first.frozen?
    assert_raises(FrozenError) { first << Dry::Validation::Rust::Message.new('is too short', path: :name) }

    set.add(Dry::Validation::Rust::Message.new('is too short', path: :name))

    refute_same first, set.messages
    assert_equal ['is invalid', 'is too short'], set.messages.map(&:text)
  end

  def test_imported_schema_can_be_reused_without_state_leaking_between_contracts
    address = Dry::Validation::Rust::Schema.Params do
      required(:city).filled(:string)
    end
    first = build_contract { params(address) { required(:name).filled(:string) } }
    second = build_contract { params(address) { required(:postal_code).value(:integer) } }

    assert first.new.call(city: 'Astana', name: 'Alexey').success?
    assert second.new.call(city: 'Astana', postal_code: '010000').success?
    assert_equal({ city: ['is missing'], postal_code: ['is missing'] }, second.new.call(name: 'Alexey').errors.to_h)
  end

  def test_inherited_schema_accepts_repeated_calls_with_deeply_frozen_input
    parent = build_contract { params { required(:profile).hash { required(:age).value(:integer) } } }
    child = Class.new(parent) { params { required(:active).value(:bool) } }
    profile = { 'age' => '42' }.freeze
    input = { 'profile' => profile, 'active' => 'true' }.freeze

    first = child.new.call(input)
    second = child.new.call(input)

    assert_equal({ profile: { age: 42 }, active: true }, first.to_h)
    assert_equal first.to_h, second.to_h
    assert_equal({ 'profile' => { 'age' => '42' }, 'active' => 'true' }, input)
    assert input.frozen?
    assert profile.frozen?
  end

  def test_duplicate_imported_key_declarations_fail_explicitly
    name = Dry::Validation::Rust::Schema.Params { required(:name).filled(:string) }
    conflicting_name = Dry::Validation::Rust::Schema.Params { required(:name).value(:integer) }

    error = assert_raises(ArgumentError) do
      build_contract { params(name, conflicting_name) }
    end

    assert_equal 'key :name is already defined', error.message
  end

  def test_native_engine_rejects_malformed_plan_json_with_argument_error
    malformed_plans = [
      '{"engine_version":',
      ('[' * 513) + (']' * 513)
    ]

    malformed_plans.each do |plan|
      error = assert_raises(ArgumentError) { Dry::Validation::Rust::Native::Engine.new(plan) }

      assert_match(/native schema plan/, error.message)
    end
  end

  def test_imported_nested_predicates_are_independent_from_the_source_schema
    address = Dry::Validation::Rust::Schema.Params do
      required(:profile).hash do
        required(:name).filled(:string, included_in?: ['Alexey'])
      end
    end
    dsl = Dry::Validation::Rust::Schema::DSL.new(mode: :params)
    dsl.import(address)
    imported_name = dsl.fields.first.children.first

    refute_same address.fields.first, dsl.fields.first
    refute_same address.fields.first.children.first, imported_name
    refute_same address.fields.first.children.first.predicates.first.argument, imported_name.predicates.first.argument

    imported_name.predicates.first.argument << 'Jane'
    imported = dsl.compile

    assert_equal({ profile: { name: ['must be one of: Alexey'] } }, address.call(profile: { name: 'Jane' }).errors.to_h)
    assert imported.call(profile: { name: 'Jane' }).success?
  end

  def test_side_by_side_namespace_does_not_define_exact_contract_alias
    code = <<~RUBY
      require "dry/validation/rust"
      abort "unexpected alias" if Dry::Validation.const_defined?(:Contract, false)
      puts Dry::Validation::Rust::Contract.name
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", '-e', code
    )
    assert status.success?, stderr
    assert_equal "Dry::Validation::Rust::Contract\n", stdout
  end

  def test_exact_compatibility_entrypoint
    code = <<~RUBY
      require "dry/validation"
      AddressSchema = Dry::Schema.Params do
        required(:city).filled(:string)
      end
      class ExactContract < Dry::Validation::Contract
        params(AddressSchema) { required(:age).value(:integer) }
      end
      result = ExactContract.new.call("city" => "Astana", "age" => "21")
      abort result.errors.to_h.inspect unless result.to_h == {city: "Astana", age: 21}
      puts "ok"
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", '-e', code
    )
    assert status.success?, stderr
    assert_equal "ok\n", stdout
  end

  def test_minimal_dry_schema_entrypoint
    code = <<~RUBY
      require "dry/schema"
      schema = Dry::Schema.Params { required(:age).value(:integer) }
      result = schema.call("age" => "21")
      abort result.errors.to_h.inspect unless result.to_h == {age: 21}
      puts "ok"
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", '-e', code
    )
    assert status.success?, stderr
    assert_equal "ok\n", stdout
  end

  def test_validate_keys_configuration_is_inherited
    parent = build_contract do
      config.validate_keys = true
      params { required(:name).value(:string) }
    end
    child = Class.new(parent)

    assert child.config.validate_keys
    assert_equal(
      { unexpected: ['is not allowed'] },
      child.new.call(name: 'Jane', unexpected: true).errors.to_h
    )
  end

  def test_compiled_contract_remains_isolated_during_concurrent_valid_and_invalid_calls
    contract = build_contract do
      params do
        required(:id).value(:integer)
        required(:tags).array(:string)
      end
    end.new

    failures = Queue.new
    threads = CONCURRENCY_THREAD_COUNT.times.map do |thread_id|
      Thread.new do
        random = Random.new(thread_id + 1)
        CONCURRENCY_CALLS_PER_THREAD.times do |index|
          input, expected_output, expected_errors = concurrent_contract_case(random, thread_id, index)
          result = contract.call(input)

          next if result.to_h == expected_output && result.errors.to_h == expected_errors

          failures << {
            thread: thread_id,
            iteration: index,
            input: input,
            output: result.to_h,
            errors: result.errors.to_h
          }
        end
      rescue StandardError => e
        failures << { thread: thread_id, error: "#{e.class}: #{e.message}" }
      end
    end
    threads.each(&:join)

    failure = failures.pop unless failures.empty?
    assert_nil failure, "concurrent contract calls failed: #{failure.inspect}"
  end

  private

  def concurrent_contract_case(random, thread_id, index)
    tags = Array.new(random.rand(1..3)) { "tag-#{thread_id}-#{index}-#{random.rand(1_000_000)}" }

    if random.rand(2).zero?
      id = random.rand(1_000_000)
      input = { 'id' => id.to_s, 'tags' => tags }
      [input, { id: id, tags: tags }, {}]
    else
      id = "invalid-#{thread_id}-#{index}-#{random.rand(1_000_000)}"
      input = { 'id' => id, 'tags' => tags }
      [input, { id: id, tags: tags }, { id: ['must be an integer'] }]
    end
  end
end
