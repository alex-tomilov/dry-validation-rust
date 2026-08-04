# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Evaluator
        # @return [Contract] contract executing the rule.
        attr_reader :contract
        # @return [Result] result receiving rule failures.
        attr_reader :result
        # @return [Array<Array<Symbol, Integer>>] paths declared for the rule.
        attr_reader :paths
        # @return [Values] validated output available to the rule.
        attr_reader :values
        # @return [Hash] mutable context for the current contract call.
        attr_reader :context
        # @return [Integer, nil] collection index for a `rule.each` evaluation.
        attr_reader :index
        # @return [Array<Message>] failures collected by execution.
        attr_reader :failures

        # Creates a rule evaluation context. This is primarily used by Contract.
        def initialize(contract:, result:, paths:, context:, default_path: paths.first || [], index: nil)
          @contract = contract
          @result = result
          @paths = paths
          @default_path = default_path
          @values = result.values
          @context = context
          @index = index
          @failures = []
          @key_failures = {}
          @base_failures = Failures.new
        end

        # Executes a rule block and macro calls, then collects their failures.
        def execute(block, macro_calls, keyword_params: [])
          execute_block(block, keyword_params) if block
          macro_calls.each { |call| execute_macro(call) }
          collect_failures
          self
        end

        # Returns the failure collector for a path, defaulting to the rule path.
        def key(path = default_path)
          normalized = Path.parse(path)
          @key_failures[normalized] ||= Failures.new(normalized)
        end

        # Returns the failure collector for base-level messages.
        def base
          @base_failures
        end

        # Returns the default rule path as a key or nested path.
        def key_name
          default_path.length == 1 ? default_path.first : default_path
        end

        # Returns the value at the rule's primary path, or nil when absent.
        def value
          raw = Path.fetch(values.data, value_path)
          raw.equal?(Path::Undefined) ? nil : raw
        end

        # Returns whether validated output contains a key or path.
        def key?(name = value_path)
          Path.key?(values.data, name)
        end

        # Returns whether the schema has an error at a path.
        def schema_error?(path)
          result.schema_error?(path)
        end

        # Alias for #schema_error?.
        alias error? schema_error?

        # Returns whether a rule error exists at a path or the default path.
        def rule_error?(path = nil)
          if path
            result.rule_error?(path)
          else
            !key(default_path).empty?
          end
        end

        # Returns whether a base-level rule error exists.
        def base_rule_error?
          !base.empty? || result.base_rule_error?
        end

        # Returns the mutable context supplied to the contract call.
        def _context
          context
        end

        # Reports contract methods delegated through this evaluator.
        def respond_to_missing?(name, include_private = false)
          contract.respond_to?(name, true) || super
        end

        private

        attr_reader :default_path

        def value_path
          paths.first || []
        end

        def execute_block(block, keyword_params, macro: nil)
          keyword_values = { context: context, index: index, macro: macro }
          kwargs = keyword_values.slice(*keyword_params)
          kwargs.empty? ? instance_exec(&block) : instance_exec(**kwargs, &block)
        end

        def execute_macro(call)
          name, *args = call
          if contract.macro_registered?(name)
            macro = contract.resolve_macro(name).with(args)
            execute_block(macro.block, macro.keyword_params, macro: macro)
          else
            execute_predicate_macro(name, args)
          end
        end

        def execute_predicate_macro(name, args)
          normalized = name.to_s.delete_suffix('?').to_sym
          expected = args.length == 1 ? args.first : args
          valid = case normalized
                  when :gt then value > expected
                  when :gteq then value >= expected
                  when :lt then value < expected
                  when :lteq then value <= expected
                  when :min_size then value.size >= expected
                  when :max_size then value.size <= expected
                  when :size then value.size == expected
                  when :format then expected.match?(value)
                  when :included_in then expected.include?(value)
                  else
                    raise UnsupportedFeatureError, "unknown rule macro #{name.inspect}"
                  end
          key.failure("must satisfy #{name}") unless valid
        end

        def collect_failures
          failures.concat(base.messages)
          @key_failures.each_value { |set| failures.concat(set.messages) }
        end

        def method_missing(name, ...)
          return contract.__send__(name, ...) if contract.respond_to?(name, true)

          super
        end
      end
    end
  end
end
