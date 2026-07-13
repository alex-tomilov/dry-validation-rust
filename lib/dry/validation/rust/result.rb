# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Result
        attr_reader :schema_result, :context

        def initialize(schema_result, context = {})
          @schema_result = schema_result
          @context = context
          @rule_messages = []
        end

        def values
          @values ||= Values.new(schema_result.to_h)
        end

        def errors(options = {})
          set = MessageSet.new([*schema_result.messages, *@rule_messages], options)
          options.empty? ? set : set.with(options)
        end

        def add_error(message)
          @rule_messages << message
          self
        end

        def success?
          errors.empty?
        end

        def failure?
          !success?
        end

        def error?(key)
          path = Path.parse(key)
          errors.any? { |message| Path.prefix?(message.path, path) }
        end

        def schema_error?(key)
          schema_result.error?(key)
        end

        def rule_error?(key)
          path = Path.parse(key)
          @rule_messages.any? { |message| Path.prefix?(message.path, path) }
        end

        def base_rule_error?
          @rule_messages.any?(&:base?)
        end

        def [](key)
          values[key]
        end

        def key?(key)
          values.key?(key)
        end

        def to_h
          values.to_h
        end

        def inspect
          context.empty? ?
            "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect}>" :
            "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect} context=#{context.inspect}>"
        end

        def deconstruct_keys(keys)
          values.deconstruct_keys(keys)
        end

        def deconstruct
          [values, context]
        end

        def finalize!
          @rule_messages.freeze
          self
        end
      end
    end
  end
end
