# frozen_string_literal: true

require_relative 'test_helper'

class SchemaStressTest < Minitest::Test
  PREDICATE_TRAVERSAL_DEPTH = 1_000

  def test_ruby_predicate_traversal_handles_deeply_nested_hashes_and_arrays
    assert_empty ruby_predicate_result(nested_hash_definitions, nested_hash_data('valid')).messages
    assert_deep_predicate_error(
      ruby_predicate_result(nested_hash_definitions, nested_hash_data('invalid')).messages,
      hash_predicate_path
    )
    assert_empty ruby_predicate_result(nested_array_definitions, nested_array_data('valid'), member: true).messages
    assert_deep_predicate_error(
      ruby_predicate_result(nested_array_definitions, nested_array_data('invalid'), member: true).messages,
      array_predicate_path
    )
  end

  private

  def ruby_predicate_result(definitions, data, member: false)
    schema = Dry::Validation::Rust::Schema.Params do
      required(:root).value(:any)
      optional(:ruby_predicate_marker).value(:string, format?: /\Aunused\z/)
    end
    root = schema.fields.first

    # The native plan has a separate 128-level guard; install the Ruby-only
    # predicate definitions after shallow native-plan compilation. The unused
    # marker enables Ruby predicate traversal for this internal stress fixture.
    member ? root.member = definitions : root.children = [definitions]

    schema.call(root: data)
  end

  def nested_hash_definitions
    leaf = field(:leaf, format?: /\Avalid\z/)
    PREDICATE_TRAVERSAL_DEPTH.downto(1) do |level|
      leaf = field(:"level_#{level}").tap { _1.children = [leaf] }
    end
    leaf
  end

  def nested_hash_data(value)
    nested = { leaf: value }
    PREDICATE_TRAVERSAL_DEPTH.downto(1) do |level|
      child = nested
      nested = {}
      nested[:"level_#{level}"] = child
    end
    nested
  end

  def nested_array_definitions
    leaf = field(nil, format?: /\Avalid\z/)
    PREDICATE_TRAVERSAL_DEPTH.times do
      nested_field = field(:nested)
      nested_field.member = leaf
      leaf = field(nil).tap { |definition| definition.children = [nested_field] }
    end
    leaf
  end

  def nested_array_data(value)
    nested = value
    PREDICATE_TRAVERSAL_DEPTH.times { nested = { nested: [nested] } }
    [nested]
  end

  def field(name, predicates = {})
    Dry::Validation::Rust::Schema::FieldDefinition.new(name: name, required: true).tap do |definition|
      predicates.each { |predicate, argument| definition.add_predicate(predicate, argument: argument) }
    end
  end

  def assert_deep_predicate_error(messages, path)
    assert_equal 1, messages.length
    assert_equal path, messages.first.path
    assert_equal :format, messages.first.code
  end

  def hash_predicate_path
    [:root, *(1..PREDICATE_TRAVERSAL_DEPTH).map { :"level_#{_1}" }, :leaf]
  end

  def array_predicate_path
    [:root, 0, *Array.new(PREDICATE_TRAVERSAL_DEPTH) { [:nested, 0] }.flatten]
  end
end
