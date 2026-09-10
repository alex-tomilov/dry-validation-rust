# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'

class RuleEvaluationBenchmarkTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, 'benchmark', 'rule_evaluation.rb')

  def test_emits_one_measurement_for_each_rule_workload
    stdout, stderr, status = Open3.capture3(
      { 'N' => '1', 'RUNS' => '1' },
      RbConfig.ruby,
      '-Ilib',
      SCRIPT,
      chdir: PROJECT_ROOT
    )

    assert_predicate status, :success?, stderr

    results = stdout.lines.map { |line| JSON.parse(line) }
    assert_equal %w[each_fail each_pass simple_fail simple_pass], results.map { |result| result.fetch('workload') }.sort
    results.each do |result|
      assert_equal 'rule_evaluation', result.fetch('benchmark')
      assert_equal 1, result.fetch('iterations')
      assert_operator result.fetch('calls_per_second'), :>, 0
      assert_operator result.fetch('ruby_objects_per_call'), :>, 0
    end
  end
end
