# frozen_string_literal: true

require_relative "test_helper"
require_relative "../examples/build_week_order_contract"

class BuildWeekDemoTest < Minitest::Test
  def test_valid_nested_input_is_normalized
    result = BuildWeekOrderContract.new.call(BuildWeekDemo.valid_input)

    assert result.success?
    assert_equal 32, result.to_h.dig(:customer, :age)
    assert_equal [2, 1], result.to_h[:items].map { |item| item[:quantity] }
    assert_equal %i[customer items], result.to_h.keys.sort
    assert_equal %i[age email], result.to_h[:customer].keys.sort
    assert result.to_h[:items].all? { |item| item.keys.sort == %i[quantity sku] }
  end

  def test_structural_and_business_rule_errors_are_combined
    result = BuildWeekOrderContract.new.call(BuildWeekDemo.invalid_input)
    errors = result.errors.to_h

    assert result.failure?
    assert errors.dig(:customer, :email)
    assert errors.dig(:items, 0, :quantity)
    assert_includes errors.dig(:customer, :age), "must be at least 18"
  end

  def test_failed_coercion_skips_the_dependent_rule
    calls = 0
    contract = BuildWeekOrderContract.new(observer: -> { calls += 1 })

    result = contract.call(BuildWeekDemo.failed_coercion_input)

    assert result.failure?
    assert result.errors.to_h.dig(:customer, :age)
    assert_equal 0, calls
  end
end
