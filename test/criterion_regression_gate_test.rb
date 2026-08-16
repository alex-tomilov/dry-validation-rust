# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'tmpdir'

class CriterionRegressionGateTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, 'script', 'compare-criterion-baselines')

  def test_accepts_estimates_at_the_five_percent_limit
    stdout, stderr, status = compare(100, 105)

    assert status.success?, stderr
    assert_includes stdout, 'within the 5% regression limit'
  end

  def test_rejects_estimates_above_the_five_percent_limit
    _stdout, stderr, status = compare(100, 105.1)

    refute status.success?
    assert_includes stderr, 'Criterion regressions exceed 5%'
    assert_includes stderr, '5.10% slower'
  end

  def test_rejects_different_benchmark_sets
    Dir.mktmpdir do |directory|
      baseline = write_baseline(directory, 100)
      candidate = write_estimate(directory, 'candidate', 'plan_compile/medium', 100)
      _stdout, stderr, status = Open3.capture3(SCRIPT, baseline, candidate)

      refute status.success?
      assert_includes stderr, 'Benchmark sets differ'
    end
  end

  private

  def compare(baseline_mean, candidate_mean)
    Dir.mktmpdir do |directory|
      baseline = write_baseline(directory, baseline_mean)
      candidate = write_estimate(directory, 'candidate', 'plan_compile/small', candidate_mean)
      return Open3.capture3(SCRIPT, baseline, candidate)
    end
  end

  def write_estimate(directory, name, benchmark, mean)
    root = File.join(directory, name)
    path = File.join(root, benchmark, 'new', 'estimates.json')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate('mean' => { 'point_estimate' => mean }))
    root
  end

  def write_baseline(directory, mean)
    path = File.join(directory, 'baseline.json')
    File.write(path, JSON.generate('benchmarks' => { 'plan_compile/small' => mean }))
    path
  end
end
