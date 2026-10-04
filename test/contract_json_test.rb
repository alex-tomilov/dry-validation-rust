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

  def test_fallback_parse_errors_and_non_object_roots_are_schema_failures
    %i[params json].each do |mode|
      contract = build_contract do
        public_send(mode) { required(:age).filled(:integer) }
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
  end

  def test_fallback_does_not_hide_processor_exceptions
    %i[params json].each do |mode|
      contract = build_contract do
        public_send(mode) do
          before(:value_coercer) { |_input| raise JSON::ParserError, 'processor failed' }
          required(:age).filled(:integer)
        end
      end.new

      error = assert_raises(JSON::ParserError) { contract.call_json('{"age":25}') }

      assert_equal 'processor failed', error.message
    end
  end

  def test_json_hooks_alone_trigger_fallback
    %i[before after].each do |stage|
      contract = build_contract do
        json do
          public_send(stage, :value_coercer) { |data| data.merge(processed: true) }
          required(:age).filled(:integer)
        end
      end.new
      contract.class.schema.engine.define_singleton_method(:call_json) { |_| raise 'hooks must use the standard path' }
      raw = '{"age":25}'
      expected = contract.call(JSON.parse(raw))
      actual = contract.call_json(raw)

      assert_equal expected.to_h, actual.to_h
      assert_equal expected.errors.to_h, actual.errors.to_h
    end
  end

  def test_json_rules_and_each_use_standard_validation_once
    [false, true].each do |each_rule|
      contract = build_contract do
        json { required(:ages).array(:integer) }
        rule_definition = rule(:ages)
        rule_definition = rule_definition.each if each_rule
        rule_definition.validate do |context:|
          context[:checks] = context.fetch(:checks, 0) + 1
          key.failure('too young') if Array(value).any? { |age| age < 18 }
        end
      end.new(default_context: { origin: 'default' })
      raw = '{"ages":[17,25]}'
      expected = contract.call(JSON.parse(raw), request_id: 2)

      contract.class.schema.engine.define_singleton_method(:call_json) { |_| raise 'rules must use the standard path' }
      actual = contract.call_json(raw, request_id: 2)
      assert_equal expected.to_h, actual.to_h
      assert_equal expected.errors.to_h, actual.errors.to_h
      assert_equal expected.context, actual.context
      assert_equal(each_rule ? 2 : 1, actual.context[:checks])
    end
  end

  def test_json_hooks_and_nested_ruby_predicates_use_standard_validation
    contract = build_contract do
      json do
        before(:value_coercer) { |input| input.merge('processed' => true) }
        after(:value_coercer) { |output| output.merge(finished: true) }
        required(:processed).filled(:bool)
        required(:items).array(:hash) { required(:email).filled(:string, format?: /@/) }
      end
    end.new
    raw = '{"items":[{"email":"invalid"},{"email":"ada@example.test"}]}'
    expected = contract.call(JSON.parse(raw))

    contract.class.schema.engine.define_singleton_method(:call_json) { |_| raise 'Ruby features must use the standard path' }
    actual = contract.call_json(raw)
    assert_equal expected.to_h, actual.to_h
    assert_equal expected.errors.to_h, actual.errors.to_h
    assert actual.to_h[:processed]
    assert actual.to_h[:finished]
    assert_equal({ items: { 0 => { email: ['is in invalid format'] } } }, actual.errors.to_h)
  end

  def test_nested_ruby_predicate_alone_triggers_fallback
    contract = build_contract do
      json { required(:profile).hash { required(:email).filled(:string, format?: /@/) } }
    end.new

    contract.class.schema.engine.define_singleton_method(:call_json) { |_| raise 'nested Ruby predicate must fall back' }
    result = contract.call_json('{"profile":{"email":"invalid"}}')
    assert_equal({ profile: { email: ['is in invalid format'] } }, result.errors.to_h)
  end

  def test_nested_lax_member_triggers_fallback
    contract = build_contract do
      json do
        required(:items).array(:hash) { required(:age).lax(:integer) }
      end
    end.new
    schema = contract.class.schema
    refute schema.engine.can_stream
    raw = '{"items":[{"age":"25"},{"age":"invalid"}]}'
    expected = contract.call(JSON.parse(raw))

    schema.engine.define_singleton_method(:call_json) { |_| raise 'nested lax member must fall back' }
    actual = contract.call_json(raw)
    assert_equal expected.to_h, actual.to_h
    assert_equal expected.errors.to_h, actual.errors.to_h
    assert_equal 25, actual.to_h[:items][0][:age]
  end

  def test_simple_json_schema_keeps_streaming
    contract = build_contract do
      json { required(:items).array(:hash) { required(:age).filled(:integer) } }
    end.new
    assert contract.class.schema.engine.can_stream

    engine = contract.class.schema.engine
    streaming_call = engine.method(:call_json)
    streamed = false
    engine.define_singleton_method(:call_json) do |raw|
      streamed = true
      streaming_call.call(raw)
    end

    assert contract.call_json('{"items":[{"age":25}]}').success?
    assert streamed
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
