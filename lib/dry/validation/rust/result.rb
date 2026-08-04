# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Result
        # @return [SchemaResult] structural validation outcome.
        attr_reader :schema_result
        # @return [Hash] context supplied to the contract call.
        attr_reader :context

        # Creates a result from a schema result and call context.
        def initialize(schema_result, context = {})
          @schema_result = schema_result
          @context = context
          @rule_messages = []
        end

        # Returns validated output wrapped in a Values object.
        def values
          @values ||= Values.new(schema_result.to_h)
        end

        # Returns schema and rule messages, optionally with display options.
        def errors(options = {})
          set = MessageSet.new([*schema_result.messages, *@rule_messages], options)
          options.empty? ? set : set.with(options)
        end

        # Adds a rule message before finalization and returns this result.
        def add_error(message)
          @rule_messages << message
          self
        end

        # Returns true when no schema or rule messages exist.
        def success?
          errors.empty?
        end

        # Returns true when at least one schema or rule message exists.
        def failure?
          !success?
        end

        # Returns whether a message exists at or below a path.
        def error?(key)
          path = Path.parse(key)
          errors.any? { |message| Path.prefix?(message.path, path) }
        end

        # Returns whether a schema message exists at or below a path.
        def schema_error?(key)
          schema_result.error?(key)
        end

        # Returns whether a rule message exists at or below a path.
        def rule_error?(key)
          path = Path.parse(key)
          @rule_messages.any? { |message| Path.prefix?(message.path, path) }
        end

        # Returns whether a base-level rule message exists.
        def base_rule_error?
          @rule_messages.any?(&:base?)
        end

        # Reads a validated value by key or path.
        def [](key)
          values[key]
        end

        # Returns whether validated output contains a key or path.
        def key?(key)
          values.key?(key)
        end

        # Returns validated output as a Hash.
        def to_h
          values.to_h
        end

        # Returns a diagnostic representation of output, errors, and context.
        def inspect
          if context.empty?
            "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect}>"
          else
            "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect} context=#{context.inspect}>"
          end
        end

        # Supports Hash pattern matching against validated output.
        def deconstruct_keys(keys)
          values.deconstruct_keys(keys)
        end

        # Supports tuple pattern matching as values and context.
        def deconstruct
          [values, context]
        end

        # Prevents further rule-message mutation and returns this result.
        def finalize!
          @rule_messages.freeze
          self
        end
      end
    end
  end
end
