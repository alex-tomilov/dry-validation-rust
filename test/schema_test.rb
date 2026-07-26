# frozen_string_literal: true

require_relative "test_helper"

class SchemaTest < Minitest::Test
  def test_params_coerces_keys_and_scalar_values
    contract = build_contract do
      params do
        required(:age).filled(:integer)
        required(:ratio).value(:float)
        required(:enabled).value(:bool)
        required(:role).value(:symbol)
        optional(:nickname).maybe(:string)
      end
    end

    result = contract.new.call(
      "age" => "42", "ratio" => "1.5", "enabled" => "false",
      "role" => "admin", "nickname" => "", "ignored" => "value"
    )

    assert result.success?
    assert_equal({age: 42, ratio: 1.5, enabled: false, role: :admin, nickname: nil}, result.to_h)
  end

  def test_schema_does_not_coerce_keys_or_values
    contract = build_contract do
      schema { required(:age).value(:integer) }
    end

    assert_equal({age: ["is missing"]}, contract.new.call("age" => "21").errors.to_h)
    assert_equal({age: ["must be an integer"]}, contract.new.call(age: "21").errors.to_h)
  end

  def test_json_coerces_keys_but_not_values
    contract = build_contract do
      json { required(:age).value(:integer) }
    end

    result = contract.new.call("age" => "21")
    assert_equal({age: "21"}, result.to_h)
    assert_equal({age: ["must be an integer"]}, result.errors.to_h)
  end

  def test_required_optional_filled_and_maybe
    contract = build_contract do
      params do
        required(:name).filled(:string)
        required(:note).maybe(:string)
        optional(:count).value(:integer)
      end
    end

    result = contract.new.call(name: "", note: nil)
    assert_equal({name: ["must be filled"]}, result.errors.to_h)
    assert_equal({name: "", note: nil}, result.to_h)
  end

  def test_schema_presence_semantics_for_symbol_keys_and_empty_containers
    contract = build_contract do
      schema do
        required(:value).value(:string)
        required(:filled).filled(:string)
        required(:maybe).maybe(:string)
        optional(:tags).filled(:array)
        optional(:metadata).filled(:hash)
      end
    end

    result = contract.new.call(value: nil, filled: nil, maybe: nil, tags: [], metadata: {})

    assert_equal(
      {value: ["must be a string"], filled: ["must be a string"], tags: ["must be filled"], metadata: ["must be filled"]},
      result.errors.to_h
    )
    assert_equal({value: nil, filled: nil, maybe: nil, tags: [], metadata: {}}, result.to_h)
  end

  def test_nested_hashes_and_arrays_are_coerced
    contract = build_contract do
      params do
        required(:profile).hash do
          required(:name).filled(:string)
          required(:age).value(:integer)
        end
        required(:scores).array(:integer)
        required(:people).array(:hash) do
          required(:id).value(:integer)
          required(:email).filled(:string)
        end
      end
    end

    result = contract.new.call(
      "profile" => {"name" => "Jane", "age" => "20"},
      "scores" => ["1", "2"],
      "people" => [{"id" => "7", "email" => "jane@example.org"}]
    )

    assert result.success?
    assert_equal 20, result[:profile][:age]
    assert_equal [1, 2], result[:scores]
    assert_equal 7, result[:people][0][:id]
  end

  def test_nested_errors_include_array_indexes
    contract = build_contract do
      params do
        required(:people).array(:hash) do
          required(:age).filled(:integer)
        end
      end
    end

    result = contract.new.call(people: [{age: "bad"}, {}])
    assert_equal(
      {people: {0 => {age: ["must be an integer"]}, 1 => {age: ["is missing"]}}},
      result.errors.to_h
    )
  end

  def test_native_and_ruby_predicates
    contract = build_contract do
      params do
        required(:age).value(:integer, gteq?: 18)
        required(:name).filled(:string, min_size?: 3)
        required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/)
        required(:role).value(:string, included_in?: %w[admin user])
      end
    end

    result = contract.new.call(age: "17", name: "Al", email: "bad", role: "root")
    assert_equal 4, result.errors.count
    assert_equal "must be greater than or equal to 18", result.errors.to_h[:age].first
  end

  def test_filled_failure_skips_native_predicates
    contract = build_contract do
      params { required(:name).filled(:string, min_size?: 3) }
    end

    assert_equal({name: ["must be filled"]}, contract.new.call(name: "").errors.to_h)
    assert_equal({name: ["size cannot be less than 3"]}, contract.new.call(name: "Al").errors.to_h)
  end

  def test_dates_times_and_decimals
    contract = build_contract do
      params do
        required(:date).value(:date)
        required(:at).value(:time)
        required(:amount).value(:decimal)
      end
    end

    result = contract.new.call(date: "2026-07-12", at: "2026-07-12T10:00:00Z", amount: "12.50")
    assert result.success?
    assert_instance_of Date, result[:date]
    assert_instance_of Time, result[:at]
    assert_instance_of BigDecimal, result[:amount]
  end

  def test_invalid_temporal_and_decimal_values_become_validation_errors
    contract = build_contract do
      params do
        required(:date).value(:date)
        required(:at).value(:time)
        required(:amount).value(:decimal)
      end
    end

    result = contract.new.call(date: "not-a-date", at: "not-a-time", amount: "not-a-number")
    assert_equal(
      {
        date: ["must be a date"],
        at: ["must be a time"],
        amount: ["must be a decimal"]
      },
      result.errors.to_h
    )
  end

  def test_input_must_be_a_hash
    contract = build_contract { params { required(:name).filled(:string) } }
    error = assert_raises(ArgumentError) { contract.new.call([]) }
    assert_match(/Input must be a Hash/, error.message)
  end
end
