# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Contract
        # The outcome of calling a {Contract}.
        #
        # A result contains coerced output, schema and rule failures, and the
        # context supplied to the call. Use {#success?} or {#failure?} to check
        # the outcome, {#to_h} to read the output, and {#errors} to inspect
        # failures.
        #
        # @example Validating input and matching the output
        #   result = UserContract.new.call(name: "Ada")
        #
        #   case result
        #   in { name: String => name }
        #     name # => "Ada"
        #   end
        #
        # @see Contract#call
        class Result
          # @return [Schema::Result] structural validation outcome.
          attr_reader :schema_result
          # @return [Hash] context supplied to the contract call.
          attr_reader :context

          # Creates a result from a schema result and call context.
          #
          # @param schema_result [Schema::Result] structural validation outcome
          # @param context [Hash] context supplied to the contract call
          # @return [Result]
          def initialize(schema_result, context = {})
            @schema_result = schema_result
            @context = context
            @rule_messages = []
          end

          # Returns validated output wrapped in a Values object.
          #
          # @return [Values] coerced output with key and path access
          def values
            @values ||= Values.new(schema_result.to_h)
          end

          # Returns schema and rule errors, optionally with display options.
          #
          # Call {MessageSet#messages} on the returned set for its immutable
          # message-object view, or {MessageSet#to_h} for nested error hashes.
          #
          # @param options [Hash] message rendering options; pass `full: true`
          #   to include full message text
          # @return [MessageSet] combined schema and rule errors
          def errors(options = {})
            set = MessageSet.new([*schema_result.messages, *@rule_messages], options)
            options.empty? ? set : set.with(options)
          end

          # Adds a rule message before finalization and returns this result.
          #
          # @param message [Message] rule failure to add
          # @return [Result] this result
          def add_error(message)
            @rule_messages << message
            self
          end

          # Returns true when no schema or rule messages exist.
          #
          # @return [Boolean]
          def success?
            errors.empty?
          end

          # Returns true when at least one schema or rule message exists.
          #
          # @return [Boolean]
          def failure?
            !success?
          end

          # Returns whether a message exists at or below a path.
          #
          # @param key [Symbol, String, Array, Hash] key or supported path specification
          # @return [Boolean]
          def error?(key)
            path = Path.parse(key)
            errors.any? { |message| Path.prefix?(message.path, path) }
          end

          # Returns whether a schema message exists at or below a path.
          #
          # @param key [Symbol, String, Array, Hash] key or supported path specification
          # @return [Boolean]
          def schema_error?(key)
            schema_result.error?(key)
          end

          # Returns whether a rule message exists at or below a path.
          #
          # @param key [Symbol, String, Array, Hash] key or supported path specification
          # @return [Boolean]
          def rule_error?(key)
            path = Path.parse(key)
            @rule_messages.any? { |message| Path.prefix?(message.path, path) }
          end

          # Returns whether a base-level rule message exists.
          #
          # @return [Boolean]
          def base_rule_error?
            @rule_messages.any?(&:base?)
          end

          # Reads a validated value by key or path.
          #
          # @param key [Symbol, String, Array] key or supported path specification
          # @return [Object, nil] coerced value, if present
          def [](key)
            values[key]
          end

          # Returns whether validated output contains a key or path.
          #
          # @param key [Symbol, String, Array] key or supported path specification
          # @return [Boolean]
          def key?(key)
            values.key?(key)
          end

          # Returns validated output as a Hash.
          #
          # @return [Hash] coerced output
          def to_h
            values.to_h
          end

          # Returns a diagnostic representation of output, errors, and context.
          #
          # @return [String]
          def inspect
            if context.empty?
              "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect}>"
            else
              "#<#{self.class}#{to_h.inspect} errors=#{errors.to_h.inspect} context=#{context.inspect}>"
            end
          end

          # Deconstructs coerced output for Hash pattern matching.
          #
          # This lets a result match as though it were its output hash, such as
          # `in { name: String => name }`. The call context is not included in
          # this matching form; use {#deconstruct} for positional matching.
          #
          # @param keys [Array<Symbol>, nil] requested keys, or +nil+ for all keys
          # @return [Hash] output entries available to the pattern
          def deconstruct_keys(keys)
            values.deconstruct_keys(keys)
          end

          # Supports tuple pattern matching as values and context.
          #
          # @return [Array<(Values, Hash)>] coerced output and call context
          def deconstruct
            [values, context]
          end

          # Prevents further rule-message mutation and returns this result.
          #
          # @return [Result] this finalized result
          def finalize!
            @rule_messages.freeze
            self
          end
        end
      end
    end
  end
end
