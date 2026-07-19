# frozen_string_literal: true

require_relative "test_helper"
require_relative "../examples/build_week_order_contract"
require "json"
require "open3"
require "tmpdir"

class BuildWeekDemoTest < Minitest::Test
  DEMO_SCRIPT = File.join(PROJECT_ROOT, "script/demo")

  def test_contract_uses_safe_namespace_and_valid_input_is_normalized
    assert_operator BuildWeekOrderContract, :<, Dry::Validation::Rust::Contract
    refute Dry::Validation.const_defined?(:Contract, false)

    result = BuildWeekOrderContract.new.call(
      "order_id" => "BW-2026-001",
      "customer" => {"email" => "jane@example.org", "age" => "27", "ignored" => true},
      "items" => [{"sku" => "RUST-BOOK", "quantity" => "2", "ignored" => true}],
      "ignored" => true
    )

    assert result.success?
    assert_equal(
      {
        order_id: "BW-2026-001",
        customer: {email: "jane@example.org", age: 27},
        items: [{sku: "RUST-BOOK", quantity: 2}]
      },
      result.to_h
    )
    assert_instance_of Integer, result[:customer][:age]
    assert_instance_of Integer, result[:items][0][:quantity]
  end

  def test_contract_merges_structural_and_ruby_rule_errors
    contract = BuildWeekOrderContract.new
    result = contract.call(
      "order_id" => "BW-2026-002",
      "customer" => {"email" => "", "age" => "16"},
      "items" => [{"sku" => "RUST-BOOK", "quantity" => "bad"}]
    )

    assert result.failure?
    assert_equal 1, contract.customer_age_rule_calls
    assert result.errors.any? { |message| message.schema? && message.path == [:customer, :email] }
    assert result.errors.any? { |message| message.schema? && message.path == [:items, 0, :quantity] }
    assert(result.errors.any? do |message|
      message.rule? && message.path == [:customer, :age] && message.text == "must be at least 18"
    end)
    assert_equal 2, result.errors.filter(:schema?).count
    assert_equal 1, result.errors.filter(:rule?).count
  end

  def test_failed_coercion_skips_dependent_rule
    contract = BuildWeekOrderContract.new
    result = contract.call(
      "order_id" => "BW-2026-003",
      "customer" => {"email" => "jane@example.org", "age" => "bad"},
      "items" => [{"sku" => "RUST-BOOK", "quantity" => "1"}]
    )

    assert result.failure?
    assert_equal "bad", result[:customer][:age]
    assert result.errors.any? { |message| message.schema? && message.path == [:customer, :age] }
    assert_equal 0, contract.customer_age_rule_calls
    refute result.errors.any? { |message| message.rule? && message.path == [:customer, :age] }
  end

  def test_demo_report_and_json_cli_are_machine_readable
    report = BuildWeekDemo.run
    assert_equal true, report.fetch("success")
    assert_equal 10, report.fetch("checks_passed")
    assert_equal 10, report.fetch("checks_total")
    assert_equal(
      %w[valid_nested_input structural_and_rule_errors failed_coercion_skips_rule],
      report.fetch("cases").map { |demo_case| demo_case.fetch("id") }
    )

    stdout, stderr, status = run_demo("--json")
    assert status.success?, stderr
    assert_empty stderr
    assert_equal report, JSON.parse(stdout)
  end

  def test_human_cli_is_concise_and_invalid_arguments_fail
    stdout, stderr, status = run_demo
    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "dry-validation-rust — deterministic demo"
    assert_includes stdout, "[1/3] Valid nested input"
    assert_includes stdout, "[2/3] Structural and Ruby rule errors"
    assert_includes stdout, "[3/3] Failed coercion skips dependent rule"
    assert_includes stdout, "Demo complete: 10 checks passed"
    assert_equal 10, stdout.lines.count { |line| line.start_with?("PASS  ") }
    refute_includes stdout.downcase, "benchmark"
    refute_includes stdout.downcase, "performance"

    invalid_stdout, invalid_stderr, invalid_status = run_demo("--yaml")
    refute invalid_status.success?
    assert_equal "", invalid_stdout
    assert_equal "Usage: script/demo [--json]\n", invalid_stderr
  end

  private

  def run_demo(*arguments)
    Open3.capture3(
      RbConfig.ruby,
      "-I#{File.join(PROJECT_ROOT, 'lib')}",
      DEMO_SCRIPT,
      *arguments,
      chdir: Dir.tmpdir
    )
  end
end
