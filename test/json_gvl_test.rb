# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

class JsonGvlTest < Minitest::Test
  def setup
    @contract = build_contract do
      json do
        required(:items).array(:integer)
      end
    end.new
  end

  def test_shared_contract_keeps_thread_outputs_and_errors_isolated
    threads = 4.times.map do |index|
      Thread.new do
        30.times.map do
          raw = JSON.generate(items: [index, 'invalid'])
          result = @contract.call_json(raw)
          [result.to_h, result.errors.to_h]
        end
      end
    end
    threads.each_with_index do |thread, index|
      thread.value.each do |output, errors|
        assert_equal({ items: [index, 'invalid'] }, output)
        assert_equal({ items: { 1 => ['must be an integer'] } }, errors)
      end
    end
  end

  def test_released_gvl_allows_input_mutation_and_gc_without_changing_output
    raw = large_input
    worker = Thread.new { @contract.call_json(raw) }
    wait_for_native_work(worker)
    raw.replace('{"items":[]}')
    GC.start
    GC.compact
    result = worker.value

    assert result.success?
    assert_equal 1_000_000, result.to_h.fetch(:items).length
    assert_equal [1], result.to_h.fetch(:items).uniq
  ensure
    worker&.join
  end

  def test_thread_raise_propagates_and_contract_remains_usable
    raw = large_input
    worker = Thread.new do
      @contract.call_json(raw)
    rescue RuntimeError => e
      e.message
    end
    wait_for_native_work(worker)
    worker.raise(RuntimeError, 'validation interrupted')

    assert_equal 'validation interrupted', worker.value
    assert_equal({ items: [2] }, @contract.call_json('{"items":[2]}').to_h)
  ensure
    worker&.join
  end

  def test_thread_kill_runs_ensure_and_contract_remains_usable
    raw = large_input
    cleaned_up = Queue.new
    worker = Thread.new do
      @contract.call_json(raw)
    ensure
      cleaned_up << true
    end
    wait_for_native_work(worker)
    worker.kill
    assert worker.join(10), 'interrupted validation did not finish'
    assert cleaned_up.pop(true)
    assert @contract.call_json('{"items":[3]}').success?
  ensure
    worker&.join
  end

  private

  def large_input
    %({"items":[#{'1,' * 999_999}1]})
  end

  def wait_for_native_work(worker)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    # This worker never sleeps or waits in Ruby. MRI marks it sleeping while
    # the native call releases the GVL. A GVL-held implementation finishes
    # before this thread can observe that state and fails the assertion.
    until worker.status == 'sleep'
      assert worker.alive?, 'validation finished without an observable GVL release'
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC), :<, deadline, 'validation did not release GVL'
      Thread.pass
    end
  end
end
