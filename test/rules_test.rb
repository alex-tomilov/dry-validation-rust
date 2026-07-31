# frozen_string_literal: true

require_relative "test_helper"

class RulesTest < Minitest::Test
  def test_rules_run_after_schema_and_can_use_value
    contract = build_contract do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure("must be an adult") if value < 18 }
    end

    assert_equal({age: ["must be an adult"]}, contract.new.call(age: "17").errors.to_h)
  end

  def test_rule_is_skipped_when_its_dependency_has_a_schema_error
    calls = []
    contract = build_contract do
      params { required(:age).value(:integer) }
      rule(:age) do
        calls << :called
        key.failure("unexpected")
      end
      define_method(:calls) { calls }
    end

    instance = contract.new
    result = instance.call(age: "bad")
    assert_empty instance.calls
    assert_equal({age: ["must be an integer"]}, result.errors.to_h)
  end

  def test_rule_is_skipped_when_a_schema_error_is_below_its_dependency
    calls = []
    contract = build_contract do
      params { required(:address).hash { required(:city).value(:integer) } }
      rule(:address) { calls << :called }
      define_method(:calls) { calls }
    end

    instance = contract.new
    instance.call(address: {city: "bad"})

    assert_empty instance.calls
  end

  def test_rule_is_skipped_when_a_schema_error_is_above_its_dependency
    calls = []
    contract = build_contract do
      params { required(:address).hash { required(:city).value(:integer) } }
      rule("address.city") { calls << :called }
      define_method(:calls) { calls }
    end

    instance = contract.new
    instance.call({})

    assert_empty instance.calls
  end

  def test_multi_key_rule_values_and_base_failure
    contract = build_contract do
      params do
        optional(:kilometers).value(:integer)
        optional(:miles).value(:integer)
      end
      rule(:kilometers, :miles) do
        base.failure("choose one distance unit") if key?(:kilometers) && key?(:miles)
      end
    end

    result = contract.new.call(kilometers: "1", miles: "2")
    assert_equal({nil => ["choose one distance unit"]}, result.errors.to_h)
    assert result.errors.first.base?
  end

  def test_nested_path_rule
    contract = build_contract do
      params do
        required(:address).hash { required(:city).filled(:string) }
      end
      rule("address.city") { key.failure("is unavailable") if value == "Nowhere" }
    end

    assert_equal(
      {address: {city: ["is unavailable"]}},
      contract.new.call(address: {city: "Nowhere"}).errors.to_h
    )
  end

  def test_multi_hash_rule_uses_the_declared_paths_as_the_default_failure_key
    contract = build_contract do
      params do
        required(:address).hash do
          required(:city).filled(:string)
          required(:zip).filled(:string)
        end
      end
      rule(address: [:city, :zip]) do
        key.failure("is unavailable") if values[:address][:city] == "Nowhere" && values[:address][:zip] == "00000"
      end
    end

    assert_equal(
      {address: {[:city, :zip] => ["is unavailable"]}},
      contract.new.call(address: {city: "Nowhere", zip: "00000"}).errors.to_h
    )
  end

  def test_rule_each_uses_index_and_item_value
    contract = build_contract do
      params { required(:numbers).array(:integer) }
      rule(:numbers).each do |index:|
        key.failure("item #{index} must be positive") if value <= 0
      end
    end

    result = contract.new.call(numbers: ["1", "0", "-2"])
    assert_equal(
      {numbers: {1 => ["item 1 must be positive"], 2 => ["item 2 must be positive"]}},
      result.errors.to_h
    )
  end

  def test_rule_each_skips_only_members_with_schema_errors
    contract = build_contract do
      params { required(:numbers).array(:integer) }
      rule(:numbers).each do |index:|
        key.failure("item #{index} must be positive") if value <= 0
      end
    end

    result = contract.new.call(numbers: ["bad", "2", "-1"])
    assert_equal(
      {
        numbers: {
          0 => ["must be an integer"],
          2 => ["item 2 must be positive"]
        }
      },
      result.errors.to_h
    )
  end

  def test_explicit_error_metadata
    contract = build_contract do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure(text: "too young", code: 123) if value < 18 }
    end

    assert_equal({age: [{text: "too young", code: 123}]}, contract.new.call(age: 10).errors.to_h)
  end

  def test_options_context_and_contract_methods
    repository = Object.new
    def repository.taken?(value) = value == "used"

    contract = build_contract do
      option :repository
      params { required(:name).filled(:string) }
      rule(:name) do |context:|
        context[:checked] = true
        key.failure("is taken") if repository.taken?(value)
      end
    end

    result = contract.new(repository: repository).call({name: "used"}, {request_id: 7})
    assert_equal({name: ["is taken"]}, result.errors.to_h)
    assert_equal({request_id: 7, checked: true}, result.context)
  end

  def test_rule_keyword_parameters_are_cached_when_the_rule_is_defined
    block = proc { |context:| context[:rule_executed] = true }
    contract = build_contract do
      params { required(:name).filled(:string) }
      rule(:name).validate(&block)
    end
    block.define_singleton_method(:parameters) { raise "rule block was introspected during evaluation" }

    result = contract.new.call({name: "Ada"}, {})

    assert_equal true, result.context[:rule_executed]
  end

  def test_macro_keyword_parameters_are_cached_when_the_macro_is_registered
    block = proc { |macro:| key.failure("must equal #{macro.args.fetch(0)}") unless value == macro.args.fetch(0) }
    contract = build_contract do
      register_macro(:equals, &block)
      params { required(:name).filled(:string) }
      rule(:name).validate(equals: "Ada")
    end
    macro = contract.macro_registry.fetch(:equals)
    macro.block.define_singleton_method(:parameters) { raise "macro block was introspected during evaluation" }

    assert_equal({name: ["must equal Ada"]}, contract.new.call(name: "Grace").errors.to_h)
  end

  def test_global_and_class_macros
    macro_name = :test_even_number
    Dry::Validation::Rust.register_macro(macro_name) do
      key.failure("must be even") unless value.even?
    end

    contract = build_contract do
      register_macro(:minimum) do |macro:|
        key.failure("is too small") if value < macro.args.fetch(0)
      end
      params { required(:number).value(:integer) }
      rule(:number).validate(macro_name, minimum: 10)
    end

    assert_equal(
      {number: ["must be even", "is too small"]},
      contract.new.call(number: "3").errors.to_h
    )
  end
end
