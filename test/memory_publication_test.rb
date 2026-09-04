# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../benchmark/schema_throughput/memory_publication'

class MemoryPublicationTest < Minitest::Test
  def test_runner_announces_calibration_and_measurement_progress
    config = SchemaThroughput::MemoryPublication::Config.from_environment({}, project_root: PROJECT_ROOT)
    runner = SchemaThroughput::MemoryPublication::Runner.new(config: config, project_root: PROJECT_ROOT)
    state = {
      'environment' => { 'git_short_sha' => 'abc123' },
      'calibrations' => {},
      'measurements' => []
    }
    scenarios = [{ 'name' => 'one' }, { 'name' => 'two' }]

    _, stderr = capture_io do
      runner.send(:announce, state, '/tmp/memory.checkpoint.json', scenarios)
      state['calibrations']['one'] = {}
      runner.send(:announce_calibration_progress, state, scenarios)
      state['measurements'] << {}
      runner.send(:announce_measurement_progress, state, scenarios)
    end

    assert_includes stderr, 'Plan: 20 isolated measurements (5 runs × 2 scenarios × 2 engines); about 40s of measured work remaining'
    assert_includes stderr, 'Calibration progress: 0/2 scenarios complete'
    assert_includes stderr, 'Calibration progress: 1/2 scenarios complete'
    assert_includes stderr, 'Measurement progress: 0/20 complete'
    assert_includes stderr, 'Measurement progress: 1/20 complete'
    assert_includes stderr, 'RESUME_FROM=/tmp/memory.checkpoint.json bundle exec script/benchmark-memory-footprint'
  end
end
