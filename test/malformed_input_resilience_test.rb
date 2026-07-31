# frozen_string_literal: true

require_relative 'test_helper'

class MalformedInputResilienceTest < Minitest::Test
  CORPUS_SIZE = 64

  def test_seeded_malformed_shape_corpus_never_raises_and_is_deterministic
    contracts = %i[params json schema].map { |mode| malformed_shape_contract(mode) }

    contracts.each do |contract|
      malformed_inputs.each do |input|
        first = contract.new.call(input)
        second = contract.new.call(input)

        assert_equal first.to_h, second.to_h
        assert_equal first.errors.to_h, second.errors.to_h
      end
    end
  end

  def test_invalid_encoded_params_value_is_a_validation_error
    contract = build_contract do
      params { required(:age).value(:integer) }
    end
    invalid_utf8 = "\xFF".dup.force_encoding(Encoding::UTF_8)

    result = contract.new.call(age: invalid_utf8)

    assert_equal({ age: invalid_utf8 }, result.to_h)
    assert_equal({ age: ['must be an integer'] }, result.errors.to_h)
  end

  def test_unsupported_declarations_fail_with_stable_errors
    declarations = [
      proc { build_contract { params { required(:age).value(:integer, unknown?: 1) } } },
      proc { build_contract { params { before(:coerce) {} } } },
      proc { build_contract { params { required(:age).value(:integer) { required(:child) } } } }
    ]

    declarations.each do |declaration|
      errors = 2.times.map do
        error = assert_raises(Dry::Validation::Rust::UnsupportedFeatureError, &declaration)
        [error.class, error.message]
      end

      assert_equal errors.first, errors.last
    end
  end

  private

  def malformed_shape_contract(mode)
    build_contract do
      public_send(mode) do
        required(:profile).hash do
          required(:age).value(:integer)
          optional(:name).maybe(:string)
        end
        required(:items).array(:hash) do
          required(:id).value(:integer)
          optional(:tags).array(:integer)
        end
        optional(:flags).array(:bool)
      end
    end
  end

  def malformed_inputs
    random = Random.new(41_917)
    Array.new(CORPUS_SIZE) do
      {
        profile: malformed_value(random, 3),
        items: malformed_value(random, 3),
        flags: malformed_value(random, 3),
        ignored: malformed_value(random, 2)
      }
    end
  end

  def malformed_value(random, depth)
    values = [nil, true, false, -1, 0, 1, 1.5, '', '42', 'not-a-value', :symbol, invalid_utf8]
    return values.fetch(random.rand(values.length)) if depth.zero?

    case random.rand(4)
    when 0 then values.fetch(random.rand(values.length))
    when 1 then Array.new(random.rand(4)) { malformed_value(random, depth - 1) }
    when 2
      Array.new(random.rand(4)).each_with_index.with_object({}) do |(_, index), hash|
        hash[index.even? ? :value : 'value'] = malformed_value(random, depth - 1)
      end
    else Object.new
    end
  end

  def invalid_utf8
    "\xFF".dup.force_encoding(Encoding::UTF_8)
  end
end
