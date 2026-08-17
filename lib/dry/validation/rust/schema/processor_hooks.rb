# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        class ProcessorHooks
          STAGES = %i[value_coercer].freeze

          def self.deep_dup(value)
            case value
            when Hash
              value.each_with_object({}) do |(key, item), copy|
                copy[deep_dup(key)] = deep_dup(item)
              end
            when Array
              value.map { |item| deep_dup(item) }
            else
              value.dup
            end
          rescue TypeError
            value
          end

          def self.register(hooks, name, block)
            unless STAGES.include?(name)
              raise ArgumentError, "Undefined step name #{name.inspect}. Available names: #{STAGES.inspect}"
            end
            raise ArgumentError, 'processor hooks require a block' unless block

            hooks << block
          end

          def self.apply(hooks, data)
            hooks.each do |hook|
              replacement = hook.call(data)
              data = replacement if replacement.is_a?(Hash)
            end
            data
          end
        end
      end
    end
  end
end
