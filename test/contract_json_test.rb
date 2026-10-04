# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

class ContractJsonTest < Minitest::Test
  def test_params_example_coerces_raw_json_and_returns_a_finalized_result
    contract = build_contract do
      params do
        required(:email).filled(:string)
        required(:age).filled(:integer)
      end
    end.new

    result = contract.call_json('{"email":"jane@example.org","age":"25"}')

    assert_instance_of Dry::Validation::Rust::Contract::Result, result
    assert result.success?
    assert_equal({ email: 'jane@example.org', age: 25 }, result.to_h)
    assert_empty result.errors.to_h
  end

  def test_both_modes_match_call_for_output_errors_rules_and_context
    %i[params json].each do |mode|
      contract = build_contract do
        public_send(mode) do
          required(:items).array(:hash) do
            required(:age).filled(:integer)
          end
        end
        rule(:items).each do |context:|
          context[:checked] = true
          key.failure('must be an adult') if value[:age] < 18
        end
      end.new(default_context: { request_id: 1, origin: 'default' })

      ['{"items":[{"age":25}]}', '{"items":[{"age":17},{"age":"invalid"}]}', '{}'].each do |raw|
        expected = contract.call(JSON.parse(raw), request_id: 2)
        actual = contract.call_json(raw, request_id: 2)

        assert_equal expected.success?, actual.success?
        assert_equal expected.to_h, actual.to_h
        assert_equal expected.errors.to_h, actual.errors.to_h
        assert_equal expected.context, actual.context
        assert_equal 2, actual.context[:request_id]
        assert_equal 'default', actual.context[:origin]
      end
    end
  end

  def test_params_path_preserves_hooks_and_ruby_predicates
    contract = build_contract do
      params do
        before(:value_coercer) { |input| input.merge('age' => '25') }
        after(:value_coercer) { |output| output.merge(processed: true) }
        required(:age).filled(:integer)
        required(:email).filled(:string, format?: /@/)
      end
    end.new
    raw = '{"email":"invalid"}'

    result = contract.call_json(raw)

    assert_equal contract.call(JSON.parse(raw)).to_h, result.to_h
    assert_equal({ age: 25, email: 'invalid', processed: true }, result.to_h)
    assert_equal({ email: ['is in invalid format'] }, result.errors.to_h)
  end

  def test_params_parse_errors_and_non_object_roots_are_schema_failures
    contract = build_contract do
      params { required(:age).filled(:integer) }
      rule(:age) { raise 'rule must be skipped on parse failure' }
    end.new

    ['{"age":', '{"age":25} trailing', '[]', 'null', '25', '"text"'].each do |raw|
      result = contract.call_json(raw)

      assert result.failure?
      assert_empty result.to_h
      message = result.errors.first
      assert_equal :json, message.code
      assert_empty message.path
      assert message.schema?
      refute_empty result.errors.to_h
    end
  end

  def test_params_path_does_not_hide_processor_exceptions
    contract = build_contract do
      params do
        before(:value_coercer) { |_input| raise JSON::ParserError, 'processor failed' }
        required(:age).filled(:integer)
      end
    end.new

    error = assert_raises(JSON::ParserError) { contract.call_json('{"age":25}') }

    assert_equal 'processor failed', error.message
  end

  def test_call_json_rejects_non_strings_in_both_modes
    %i[params json].each do |mode|
      contract = build_contract { public_send(mode) { required(:age).filled(:integer) } }.new

      [nil, 25, { age: 25 }].each do |input|
        error = assert_raises(ArgumentError) { contract.call_json(input) }

        assert_includes error.message, 'JSON input must be a String'
      end
    end
  end

  def test_call_json_requires_a_schema
    assert_raises(Dry::Validation::Rust::SchemaMissingError) do
      build_contract.new.call_json('{}')
    end
  end

  def test_schema_mode_remains_explicitly_unsupported
    contract = build_contract { schema { required(:age).filled(:integer) } }.new

    error = assert_raises(ArgumentError) { contract.call_json('{"age":25}') }

    assert_equal 'call_json requires a params or json schema', error.message
  end
end
