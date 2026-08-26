# frozen_string_literal: true

module SchemaThroughput
  # Scenario definitions and their payload builders form one cohesive benchmark matrix.
  # rubocop:disable Metrics/ModuleLength
  module Scenarios
    module_function

    def selected(filter)
      return all unless filter

      scenarios = all.select { |scenario| scenario.fetch('name') == filter }
      return scenarios unless scenarios.empty?

      names = all.map { |scenario| scenario.fetch('name') }.join(', ')
      abort "Unknown SCENARIO=#{filter.inspect}. Use one of: #{names}"
    end

    def all
      @all ||= [
        {
          'name' => 'small_form',
          'description' => '5-field web request baseline; all calls valid',
          'source' => flat_schema(5),
          'payloads' => [flat_payload(5)]
        },
        {
          'name' => 'medium_form',
          'description' => '25-field API payload; 80% of calls valid',
          'source' => flat_schema(25),
          'payloads' => Array.new(4, flat_payload(25)) + [flat_payload(25, invalid: true)]
        },
        {
          'name' => 'large_form',
          'description' => '100-field stress case; 50% of calls valid',
          'source' => flat_schema(100),
          'payloads' => [flat_payload(100), flat_payload(100, invalid: true)]
        },
        {
          'name' => 'nested_object',
          'description' => '10-level object traversal; all calls valid',
          'source' => nested_schema(10),
          'payloads' => [nested_payload(10)]
        },
        {
          'name' => 'array_of_objects',
          'description' => '100 objects with 5 fields each; 90% of calls valid',
          'source' => <<~RUBY,
            required(:items).array(:hash) do
              required(:id).value(:integer, gt?: 0)
              required(:name).filled(:string)
              required(:age).value(:integer, gteq?: 18)
              required(:active).value(:bool)
              required(:role).filled(:string)
            end
          RUBY
          'payloads' => Array.new(9, array_payload) + [array_payload(invalid: true)]
        },
        {
          'name' => 'all_invalid',
          'description' => '20 fields with every value invalid; error-path allocation case',
          'source' => flat_schema(20),
          'payloads' => [flat_payload(20, invalid: true)]
        },
        {
          'name' => 'sparse_optional',
          'description' => '50 optional fields with only 20% present; missing-key traversal case',
          'source' => optional_schema(50),
          'payloads' => [sparse_optional_payload(50)]
        },
        {
          'name' => 'mixed_types',
          'description' => '20 fields across integer, float, bool, and string coercion paths; all calls valid',
          'source' => mixed_types_schema(5),
          'payloads' => [mixed_types_payload(5)]
        },
        {
          'name' => 'array_of_primitives',
          'description' => '500 integer values in one primitive array; all calls valid',
          'source' => 'required(:ids).array(:integer)',
          'payloads' => [{ 'ids' => Array.new(500) { |index| (index + 1).to_s } }]
        },
        {
          'name' => 'wide_nested_object',
          'description' => '10 sibling hashes with 10 integer fields each; broad nested traversal',
          'source' => wide_nested_schema(groups: 10, fields_per_group: 10),
          'payloads' => [wide_nested_payload(groups: 10, fields_per_group: 10)]
        },
        {
          'name' => 'ruby_rules',
          'description' => '10 schema fields plus 10 Ruby-owned rules; 80% of calls rule-valid',
          'source' => flat_schema(10),
          'rules_source' => even_rules(10),
          'payloads' => Array.new(4, rule_payload(10)) + [rule_payload(10, invalid_rule: true)]
        }
      ].freeze
    end

    def flat_schema(field_count)
      (0...field_count).map do |index|
        "required(:field_#{index}).value(:integer, gt?: 0)"
      end.join("\n")
    end
    private_class_method :flat_schema

    def flat_payload(field_count, invalid: false)
      (0...field_count).to_h do |index|
        ["field_#{index}", invalid ? 'invalid' : (index + 1).to_s]
      end
    end
    private_class_method :flat_payload

    def optional_schema(field_count)
      (0...field_count).map do |index|
        "optional(:field_#{index}).value(:integer, gt?: 0)"
      end.join("\n")
    end
    private_class_method :optional_schema

    def sparse_optional_payload(field_count)
      (0...field_count).step(5).to_h do |index|
        ["field_#{index}", (index + 1).to_s]
      end
    end
    private_class_method :sparse_optional_payload

    def mixed_types_schema(groups)
      (0...groups).flat_map do |index|
        [
          "required(:integer_#{index}).value(:integer, gt?: 0)",
          "required(:float_#{index}).value(:float, gt?: 0.0)",
          "required(:bool_#{index}).value(:bool)",
          "required(:string_#{index}).filled(:string)"
        ]
      end.join("\n")
    end
    private_class_method :mixed_types_schema

    def mixed_types_payload(groups)
      (0...groups).each_with_object({}) do |index, payload|
        payload["integer_#{index}"] = (index + 1).to_s
        payload["float_#{index}"] = format('%.2f', index + 1.25)
        payload["bool_#{index}"] = index.even? ? 'true' : 'false'
        payload["string_#{index}"] = "value-#{index}"
      end
    end
    private_class_method :mixed_types_payload

    def nested_schema(depth)
      openings = (0...depth).map { |index| "required(:level_#{index}).hash do" }
      (openings + ['required(:value).value(:integer, gt?: 0)'] + Array.new(depth, 'end')).join("\n")
    end
    private_class_method :nested_schema

    def nested_payload(depth)
      (depth - 1).downto(0).reduce({ 'value' => '1' }) do |payload, index|
        { "level_#{index}" => payload }
      end
    end
    private_class_method :nested_payload

    def wide_nested_schema(groups:, fields_per_group:)
      (0...groups).map do |group|
        fields = (0...fields_per_group).map do |field|
          "  required(:field_#{field}).value(:integer, gt?: 0)"
        end.join("\n")
        "required(:group_#{group}).hash do\n#{fields}\nend"
      end.join("\n")
    end
    private_class_method :wide_nested_schema

    def wide_nested_payload(groups:, fields_per_group:)
      (0...groups).to_h do |group|
        fields = (0...fields_per_group).to_h do |field|
          ["field_#{field}", (field + 1).to_s]
        end
        ["group_#{group}", fields]
      end
    end
    private_class_method :wide_nested_payload

    def array_payload(invalid: false)
      items = Array.new(100) do |index|
        {
          'id' => invalid && index.zero? ? 'invalid' : (index + 1).to_s,
          'name' => invalid && index.zero? ? '' : "person-#{index}",
          'age' => invalid && index.zero? ? 'invalid' : '30',
          'active' => 'true',
          'role' => 'member'
        }
      end
      { 'items' => items }
    end
    private_class_method :array_payload

    def even_rules(field_count)
      (0...field_count).map do |index|
        <<~RUBY
          rule(:field_#{index}) do
            key.failure('must be even') if value.odd?
          end
        RUBY
      end.join("\n")
    end
    private_class_method :even_rules

    def rule_payload(field_count, invalid_rule: false)
      (0...field_count).to_h do |index|
        value = invalid_rule && index.zero? ? 3 : (index + 1) * 2
        ["field_#{index}", value.to_s]
      end
    end
    private_class_method :rule_payload
  end
  # rubocop:enable Metrics/ModuleLength
end
