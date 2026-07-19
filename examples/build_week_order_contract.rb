# frozen_string_literal: true

# Deterministic Build Week order demo. Rust owns key normalization, filtering,
# coercion, nested traversal, native predicates, and structural errors in this
# scenario. Ruby owns the contract DSL, the adult-customer business rule, and
# the observable rule-call counter. This uses the safe side-by-side namespace;
# it does not prove full upstream compatibility or universal performance.

require "dry/validation/rust"

class BuildWeekOrderContract < Dry::Validation::Rust::Contract
  attr_reader :customer_age_rule_calls

  params do
    required(:order_id).filled(:string)

    required(:customer).hash do
      required(:email).filled(:string)
      required(:age).value(:integer)
    end

    required(:items).array(:hash) do
      required(:sku).filled(:string)
      required(:quantity).value(:integer, gt?: 0)
    end
  end

  rule("customer.age") do
    record_customer_age_rule_call
    key.failure("must be at least 18") if value < 18
  end

  def initialize(default_context: {}, **options)
    @customer_age_rule_calls = 0
    super
  end

  private

  def record_customer_age_rule_call
    @customer_age_rule_calls += 1
  end
end

module BuildWeekDemo
  module_function

  def run
    cases = [valid_case, combined_errors_case, skipped_rule_case]
    checks = cases.flat_map { |demo_case| demo_case.fetch("checks") }

    {
      "demo" => "dry-validation-rust deterministic order validation",
      "success" => checks.all? { |check| check.fetch("success") },
      "checks_passed" => checks.count { |check| check.fetch("success") },
      "checks_total" => checks.length,
      "cases" => cases
    }
  end

  def valid_case
    contract = BuildWeekOrderContract.new
    result = contract.call(
      "order_id" => "BW-2026-001",
      "customer" => {
        "email" => "jane@example.org",
        "age" => "27",
        "loyalty_tier" => "gold"
      },
      "items" => [
        {"sku" => "RUST-BOOK", "quantity" => "2", "price" => "29.00"},
        {"sku" => "RUBY-GEM", "quantity" => "1", "price" => "19.00"}
      ],
      "internal_note" => "not part of the schema"
    )

    expected_output = {
      order_id: "BW-2026-001",
      customer: {email: "jane@example.org", age: 27},
      items: [
        {sku: "RUST-BOOK", quantity: 2},
        {sku: "RUBY-GEM", quantity: 1}
      ]
    }

    build_case("valid_nested_input", "Valid nested input") do |checks|
      check(checks, "result succeeded") { result.success? }
      check(checks, "string keys normalized and unknown keys filtered") { result.to_h == expected_output }
      check(checks, "customer age coerced to Integer") { result[:customer][:age].instance_of?(Integer) }
      check(checks, "nested item quantities coerced to Integer") do
        result[:items].map { |item| item[:quantity] } == [2, 1] &&
          result[:items].all? { |item| item[:quantity].instance_of?(Integer) }
      end
    end
  end

  def combined_errors_case
    contract = BuildWeekOrderContract.new
    result = contract.call(
      "order_id" => "BW-2026-002",
      "customer" => {"email" => "", "age" => "16"},
      "items" => [{"sku" => "RUST-BOOK", "quantity" => "not-an-integer"}]
    )

    build_case("structural_and_rule_errors", "Structural and Ruby rule errors") do |checks|
      check(checks, "blank customer email reported by schema") do
        message?(result, [:customer, :email], source: :schema, code: :filled)
      end
      check(checks, "items[0].quantity coercion error reported") do
        message?(result, [:items, 0, :quantity], source: :schema, code: :type)
      end
      check(checks, "underage customer rejected by Ruby rule") do
        contract.customer_age_rule_calls == 1 &&
          message?(result, [:customer, :age], source: :rule, text: "must be at least 18")
      end
      check(checks, "schema and Ruby errors merged in one result") do
        result.failure? && result.errors.filter(:schema?).count == 2 && result.errors.filter(:rule?).count == 1
      end
    end
  end

  def skipped_rule_case
    contract = BuildWeekOrderContract.new
    result = contract.call(
      "order_id" => "BW-2026-003",
      "customer" => {"email" => "jane@example.org", "age" => "not-an-integer"},
      "items" => [{"sku" => "RUST-BOOK", "quantity" => "1"}]
    )

    build_case("failed_coercion_skips_rule", "Failed coercion skips dependent rule") do |checks|
      check(checks, "customer age integer coercion failed") do
        result.failure? && result[:customer][:age] == "not-an-integer" &&
          message?(result, [:customer, :age], source: :schema, code: :type)
      end
      check(checks, "dependent customer age rule did not execute") do
        contract.customer_age_rule_calls.zero? &&
          result.errors.none? { |message| message.path == [:customer, :age] && message.rule? }
      end
    end
  end

  def build_case(id, title)
    checks = []
    yield checks
    {"id" => id, "title" => title, "success" => checks.all? { |check| check.fetch("success") }, "checks" => checks}
  end
  private_class_method :build_case

  def check(checks, name)
    passed = yield
    checks << {
      "name" => name,
      "success" => !!passed,
      "detail" => passed ? nil : "expectation returned false"
    }
  rescue StandardError => error
    checks << {
      "name" => name,
      "success" => false,
      "detail" => "#{error.class}: #{error.message}"
    }
  end
  private_class_method :check

  def message?(result, path, source:, code: nil, text: nil)
    result.errors.any? do |message|
      message.path == path && message.source == source &&
        (code.nil? || message.code == code) &&
        (text.nil? || message.text == text)
    end
  end
  private_class_method :message?
end
