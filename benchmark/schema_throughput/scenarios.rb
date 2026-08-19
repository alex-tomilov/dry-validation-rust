# frozen_string_literal: true

module SchemaThroughput
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
  end
end
