# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/concurrency_benchmark'

class ConcurrencyBenchmarkTest < Minitest::Test
  def test_runs_all_thread_counts_and_reports_normalized_scaling
    stdout, = capture_io { ConcurrencyBenchmark.run(iterations: 1) }

    %w[rust-1t rust-2t rust-4t upstream-1t upstream-2t upstream-4t].each do |label|
      assert_includes stdout, label
    end
    assert_includes stdout, 'Normalized scaling'
    assert_match(/rust: 1t=1\.00x, 2t=\d+\.\d{2}x, 4t=\d+\.\d{2}x/, stdout)
    assert_match(/upstream: 1t=1\.00x, 2t=\d+\.\d{2}x, 4t=\d+\.\d{2}x/, stdout)
  end

  def test_rejects_non_positive_iteration_counts
    error = assert_raises(ArgumentError) { ConcurrencyBenchmark.run(iterations: 0) }

    assert_equal 'ITERATIONS must be positive', error.message
  end
end
