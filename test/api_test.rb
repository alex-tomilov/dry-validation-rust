# frozen_string_literal: true

require_relative "test_helper"
require "open3"

class ApiTest < Minitest::Test
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
    result = contract.call(name: "Jane")

    matched = case result
              in {name:}
                name
              end
    assert_equal "Jane", matched
  end

  def test_schema_and_rule_inheritance
    parent = build_contract do
      params { required(:name).filled(:string) }
      rule(:name) { key.failure("is blocked") if value == "blocked" }
    end
    child = Class.new(parent) do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure("too young") if value < 18 }
    end

    result = child.new.call(name: "blocked", age: "10")
    assert_equal({name: ["is blocked"], age: ["too young"]}, result.errors.to_h)
  end

  def test_external_schema_reuse
    address = Dry::Validation::Rust::Schema.Params do
      required(:city).filled(:string)
    end
    contract = build_contract do
      params(address) { required(:name).filled(:string) }
    end

    assert contract.new.call(city: "Astana", name: "Alexey").success?
  end

  def test_imported_schema_can_be_reused_without_state_leaking_between_contracts
    address = Dry::Validation::Rust::Schema.Params do
      required(:city).filled(:string)
    end
    first = build_contract { params(address) { required(:name).filled(:string) } }
    second = build_contract { params(address) { required(:postal_code).value(:integer) } }

    assert first.new.call(city: "Astana", name: "Alexey").success?
    assert second.new.call(city: "Astana", postal_code: "010000").success?
    assert_equal({city: ["is missing"], postal_code: ["is missing"]}, second.new.call(name: "Alexey").errors.to_h)
  end

  def test_inherited_schema_accepts_repeated_calls_with_deeply_frozen_input
    parent = build_contract { params { required(:profile).hash { required(:age).value(:integer) } } }
    child = Class.new(parent) { params { required(:active).value(:bool) } }
    profile = {"age" => "42".freeze}.freeze
    input = {"profile" => profile, "active" => "true".freeze}.freeze

    first = child.new.call(input)
    second = child.new.call(input)

    assert_equal({profile: {age: 42}, active: true}, first.to_h)
    assert_equal first.to_h, second.to_h
    assert_equal({"profile" => {"age" => "42"}, "active" => "true"}, input)
    assert input.frozen?
    assert profile.frozen?
  end

  def test_duplicate_imported_key_declarations_fail_explicitly
    name = Dry::Validation::Rust::Schema.Params { required(:name).filled(:string) }
    conflicting_name = Dry::Validation::Rust::Schema.Params { required(:name).value(:integer) }

    error = assert_raises(ArgumentError) do
      build_contract { params(name, conflicting_name) }
    end

    assert_equal "key :name is already defined", error.message
  end

  def test_imported_nested_predicates_are_independent_from_the_source_schema
    address = Dry::Validation::Rust::Schema.Params do
      required(:profile).hash do
        required(:name).filled(:string, included_in?: ["Alexey"])
      end
    end
    dsl = Dry::Validation::Rust::Schema::DSL.new(mode: :params)
    dsl.import(address)
    imported_name = dsl.fields.first.children.first

    refute_same address.fields.first, dsl.fields.first
    refute_same address.fields.first.children.first, imported_name
    refute_same address.fields.first.children.first.predicates.first.argument, imported_name.predicates.first.argument

    imported_name.predicates.first.argument << "Jane"
    imported = dsl.compile

    assert_equal({profile: {name: ["must be one of: Alexey"]}}, address.call(profile: {name: "Jane"}).errors.to_h)
    assert imported.call(profile: {name: "Jane"}).success?
  end

  def test_side_by_side_namespace_does_not_define_exact_contract_alias
    code = <<~'RUBY'
      require "dry/validation/rust"
      abort "unexpected alias" if Dry::Validation.const_defined?(:Contract, false)
      puts Dry::Validation::Rust::Contract.name
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", "-e", code
    )
    assert status.success?, stderr
    assert_equal "Dry::Validation::Rust::Contract\n", stdout
  end

  def test_exact_compatibility_entrypoint
    code = <<~'RUBY'
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
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", "-e", code
    )
    assert status.success?, stderr
    assert_equal "ok\n", stdout
  end

  def test_minimal_dry_schema_entrypoint
    code = <<~'RUBY'
      require "dry/schema"
      schema = Dry::Schema.Params { required(:age).value(:integer) }
      result = schema.call("age" => "21")
      abort result.errors.to_h.inspect unless result.to_h == {age: 21}
      puts "ok"
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I#{File.expand_path('../lib', __dir__)}", "-e", code
    )
    assert status.success?, stderr
    assert_equal "ok\n", stdout
  end

  def test_unsupported_strict_key_configuration_fails_loudly
    error = assert_raises(Dry::Validation::Rust::UnsupportedFeatureError) do
      Class.new(Dry::Validation::Rust::Contract) do
        config.validate_keys = true
      end
    end
    assert_match(/validate_keys/, error.message)
  end

  def test_compiled_contract_is_thread_safe_under_parallel_calls
    contract = build_contract do
      params do
        required(:id).value(:integer)
        required(:tags).array(:string)
      end
    end.new

    failures = Queue.new
    threads = 8.times.map do |thread_id|
      Thread.new do
        100.times do |index|
          result = contract.call("id" => (thread_id * 100 + index).to_s, "tags" => ["a", "b"])
          failures << result unless result.success? && result[:id].is_a?(Integer)
        end
      end
    end
    threads.each(&:join)
    assert failures.empty?
  end
end
