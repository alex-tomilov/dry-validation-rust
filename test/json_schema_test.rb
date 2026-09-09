# frozen_string_literal: true

require_relative 'test_helper'

class JsonSchemaTest < Minitest::Test
  def test_contract_generates_a_nested_draft_seven_schema
    contract = build_contract do
      params do
        required(:profile).hash do
          required(:age).value(:integer, gteq?: 18)
          optional(:tags).maybe.array(:string)
        end
      end
    end

    assert_equal(
      {
        '$schema': 'http://json-schema.org/draft-07/schema#',
        type: 'object',
        properties: {
          profile: {
            type: 'object',
            properties: {
              age: { type: 'integer', minimum: 18 },
              tags: {
                anyOf: [
                  { type: 'array', items: { type: 'string' } },
                  { type: 'null' }
                ]
              }
            },
            required: ['age']
          }
        },
        required: ['profile']
      },
      contract.json_schema
    )
  end

  def test_contract_json_schema_requires_a_schema
    contract = Class.new(Dry::Validation::Rust::Contract)

    error = assert_raises(Dry::Validation::Rust::SchemaMissingError) { contract.json_schema }

    assert_equal "#{contract} must define a schema before generating JSON Schema", error.message
  end

  def test_contract_json_schema_rejects_unknown_keys_when_configured
    contract = build_contract do
      config.validate_keys = true

      params do
        required(:profile).hash do
          required(:name).filled(:string)
        end
      end
    end

    schema = contract.json_schema

    assert_equal false, schema[:additionalProperties]
    assert_equal false, schema[:properties][:profile][:additionalProperties]
  end
end
