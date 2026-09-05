# frozen_string_literal: true

require_relative 'test_helper'

class NativeSerializationTest < Minitest::Test
  def contract
    build_contract do
      json do
        required(:id).value(:integer)
        optional(:name).value(:string)
        optional(:items).array(:hash) do
          required(:label).value(:string)
        end
      end
      rule(:id) { key.failure('must be positive') if value.negative? }
    end.new
  end

  def test_serializes_output_from_both_entrypoints
    input = { id: 42, name: "héllo\n\"\\\u0000", items: [{ label: 'one' }] }
    [contract.call(input), contract.call_json(JSON.generate(input))].each do |result|
      assert_equal JSON.parse(JSON.generate(result.to_h)), JSON.parse(result.to_json)
      assert_equal Encoding::UTF_8, result.to_json.encoding
    end
    assert_equal '{"id":1}', contract.call(id: 1).to_json
    assert_equal '{"id":1,"items":[]}', contract.call(id: 1, items: []).to_json
  end

  def test_serializes_coerced_primitive_arrays_without_hash_json_dispatch
    instance = build_contract do
      params { required(:ids).array(:integer) }
    end.new
    result = instance.call(ids: %w[1 2])
    result.to_h.define_singleton_method(:to_json) { |*| raise 'Ruby Hash JSON dispatch' }
    assert_equal '{"ids":[1,2]}', result.to_json
    assert_equal result.to_json, result.to_json(nil)
    assert_raises(ArgumentError) { JSON.generate(result) }
  end

  def test_rule_failures_serialize_output_without_errors_or_context
    result = contract.call({ id: -1 }, trace: 'secret')
    assert result.failure?
    assert_equal '{"id":-1}', result.to_json
  end

  def test_invalid_and_mutated_output_fails_explicitly
    assert_raises(ArgumentError) { contract.call(id: 'wrong').to_json }
    assert_raises(RangeError) { contract.call(id: 2**63).to_json }
    result = contract.call(id: 1)
    result.to_h[:extra] = 'unexpected'
    assert_raises(ArgumentError) { result.to_json }
    assert_raises(ArgumentError) { contract.call(id: 1).to_json(indent: '  ') }
  end

  def test_unsupported_schemas_still_validate
    instance = build_contract do
      params do
        required(:active).value(:bool)
      end
    end.new
    result = instance.call(active: true)
    assert result.success?
    assert_raises(ArgumentError) { result.to_json }
    nullable = build_contract do
      params do
        required(:name).maybe(:string)
      end
    end.new
    assert_raises(ArgumentError) { nullable.call(name: nil).to_json }
  end

  def test_result_keeps_engine_and_dynamic_keys_alive
    name = "dynamic_#{object_id}"
    instance = build_contract do
      json { required(name.to_sym).value(:integer) }
    end.new
    result = instance.call(name.to_sym => 7)
    instance = nil # rubocop:disable Lint/UselessAssignment -- Drop the contract before exercising GC.
    GC.start
    GC.compact
    assert_equal({ name => 7 }, JSON.parse(result.to_json))
  end

  def test_manually_constructed_result_requires_engine
    result = Dry::Validation::Rust::Contract::Result.new(contract.call(id: 1).schema_result)
    assert_raises(ArgumentError) { result.to_json }
  end
end
