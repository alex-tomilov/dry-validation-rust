# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'

class PluginNoopOverheadScriptTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, 'script', 'check-plugin-noop-overhead')

  def test_accepts_noop_path_within_one_percent
    stdout, stderr, status = run_check(100, 100.5)

    assert status.success?, stderr
    assert_includes stdout, 'within the 1% limit at 95% confidence'
  end

  def test_rejects_noop_path_more_than_one_percent_different
    _stdout, stderr, status = run_check(100, 101.01)

    refute status.success?
    assert_includes stderr, 'NOOP plugin overhead exceeds 1% at 95% confidence'
  end

  private

  def run_check(without, noop)
    Dir.mktmpdir do |directory|
      write_estimate(directory, 'plugin_overhead_validate_without_plugin', without)
      write_estimate(directory, 'plugin_overhead_validate_with_noop_plugin', noop)
      return ExecutableScriptTestHelper.capture(SCRIPT, directory)
    end
  end

  def write_estimate(directory, benchmark, mean)
    path = File.join(directory, benchmark, 'new', 'estimates.json')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate(
                       'mean' => {
                         'point_estimate' => mean,
                         'confidence_interval' => {
                           'confidence_level' => 0.95,
                           'lower_bound' => mean * 0.999,
                           'upper_bound' => mean * 1.001
                         }
                       }
                     ))
  end
end
