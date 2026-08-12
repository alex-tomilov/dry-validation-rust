# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'rbconfig'

class FuzzEngineTest < Minitest::Test
  ITERATIONS = 192
  SEED = 91_337

  def test_seeded_hostile_hash_corpus_does_not_crash_the_ruby_process
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, '-Ilib', '-e', fuzz_script,
      chdir: PROJECT_ROOT
    )

    assert status.success?, <<~MESSAGE
      Engine fuzz subprocess exited with #{status.inspect}.
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE
  end

  private

  def fuzz_script
    <<~RUBY
      require 'dry/validation/rust'

      class ExplosiveKey
        def to_s
          raise 'unexpected keys may reject hostile #to_s implementations'
        end
      end

      contract = Class.new(Dry::Validation::Rust::Contract) do
        config.validate_keys = true

        params do
          required(:profile).hash do
            optional(:details).hash { optional(:name).value(:string) }
          end
          optional(:items).array(:hash) { optional(:id).value(:integer) }
          optional(:enabled).value(:bool)
        end
      end.new

      def random_value(random, depth)
        values = [nil, true, false, -1, 0, 1, 1.5, '', '42', :symbol, Object.new, /value/]
        return values.fetch(random.rand(values.length)) if depth.zero?

        case random.rand(4)
        when 0 then values.fetch(random.rand(values.length))
        when 1 then Array.new(random.rand(4)) { random_value(random, depth - 1) }
        when 2
          Array.new(random.rand(4)).each_with_index.with_object({}) do |(_, index), hash|
            hash[index.even? ? :value : 'value'] = random_value(random, depth - 1)
          end
        else Object.new
        end
      end

      def deeply_nested_hash
        300.times.reduce({ leaf: 'value' }) { |value| { nested: value } }
      end

      def cyclic_hash
        hash = { details: { name: 'Ada' } }
        hash[:cycle] = hash
        hash
      end

      def cyclic_array
        array = []
        array << array
        array
      end

      def default_proc_hash
        Hash.new do |_hash, _key|
          raise 'native lookup must not turn a missing key into a crash'
        end
      end

      inputs = [
        { profile: cyclic_hash },
        { profile: { details: deeply_nested_hash } },
        { profile: { details: cyclic_hash }, items: cyclic_array },
        { profile: default_proc_hash, ExplosiveKey.new => Object.new }
      ]
      random = Random.new(#{SEED})
      #{ITERATIONS}.times do
        input = {
          profile: random_value(random, 5),
          items: random_value(random, 5),
          enabled: random_value(random, 2)
        }
        input[ExplosiveKey.new] = random_value(random, 3) if random.rand(4).zero?
        inputs << input
      end

      inputs.each do |input|
        contract.call(input)
      rescue StandardError
        # Validation failures and Ruby callback errors are permitted. A native
        # crash, abort, or unwound Magnus exception terminates this subprocess.
      end
    RUBY
  end
end
