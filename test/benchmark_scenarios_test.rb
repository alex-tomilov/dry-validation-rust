# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/schema_throughput/scenarios'

class BenchmarkScenariosTest < Minitest::Test
  NEW_SCENARIOS = %w[
    sparse_optional
    mixed_types
    array_of_primitives
    wide_nested_object
    ruby_rules
  ].freeze

  def test_matrix_has_unique_named_scenarios
    scenarios = SchemaThroughput::Scenarios.all
    names = scenarios.map { |scenario| scenario.fetch('name') }

    assert_equal names.uniq, names
    assert_equal 11, names.length
  end

  def test_new_scenarios_are_present_and_have_payloads
    scenarios = SchemaThroughput::Scenarios.all.to_h { |scenario| [scenario.fetch('name'), scenario] }

    NEW_SCENARIOS.each do |name|
      scenario = scenarios.fetch(name)
      refute_empty scenario.fetch('description')
      refute_empty scenario.fetch('source')
      refute_empty scenario.fetch('payloads')
    end
  end

  def test_ruby_rules_scenario_exercises_ruby_owned_rules
    scenario = SchemaThroughput::Scenarios.selected('ruby_rules').fetch(0)

    assert_includes scenario.fetch('rules_source'), 'rule(:field_0)'
    assert_equal 5, scenario.fetch('payloads').length
  end

  def test_unknown_filter_is_not_silently_accepted
    error = assert_raises(SystemExit) do
      SchemaThroughput::Scenarios.selected('not-a-real-scenario')
    end

    assert_equal 1, error.status
  end
end
