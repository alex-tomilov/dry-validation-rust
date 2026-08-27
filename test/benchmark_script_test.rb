# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

class BenchmarkScriptTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, 'script', 'benchmark')

  def test_wrapper_runs_the_harness_from_outside_the_project_directory
    stdout, stderr, status = ExecutableScriptTestHelper.capture(
      SCRIPT,
      environment: {
        'ENGINE' => 'rust',
        'FORMAT' => 'json',
        'SCENARIO' => 'small_form',
        'N' => '1',
        'WARMUP' => '0',
        'LATENCY_SAMPLES' => '1'
      },
      chdir: '/tmp'
    )

    assert_predicate status, :success?, stderr
    assert_equal 'schema_throughput_matrix', JSON.parse(stdout).fetch('benchmark')
  end
end
