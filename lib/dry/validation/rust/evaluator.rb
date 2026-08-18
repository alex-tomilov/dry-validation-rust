# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      # The evaluation context for contract rules.
      #
      # Inside a {Contract.rule rule} block, `self` is an Evaluator instance.
      # It exposes the validated values, the rule path, error collectors, and
      # the mutable per-call context.
      #
      # @example Add a failure for the rule value
      #   rule(:age) { key.failure("must be at least 18") if value < 18 }
      class Evaluator
        # Returns the contract executing the rule.
        #
        # @return [Contract]
        # @example Read a contract option from a rule
        #   rule(:name) { key.failure("is reserved") if contract.reserved?(value) }
        attr_reader :contract
        # Returns the result receiving rule failures.
        #
        # @return [Contract::Result]
        # @example Inspect a schema error before adding a rule failure
        #   rule(:email) { key.failure("is unavailable") unless result.schema_error?(:email) }
        attr_reader :result
        # Returns the paths declared for the rule.
        #
        # @return [Array<Array<Symbol, Integer>>]
        # @example Use the current rule path
        #   rule(:email) { paths # => [[:email]] }
        attr_reader :paths
        # Returns all validated output available to the rule.
        #
        # @return [Contract::Values]
        # @example Compare two validated values
        #   rule(:password_confirmation) { key.failure("does not match") if value != values[:password] }
        attr_reader :values
        # Returns the mutable context for the current contract call.
        #
        # @return [Hash]
        # @example Read context supplied to {Contract#call}
        #   rule(:role) { key.failure("is not allowed") unless context[:roles].include?(value) }
        attr_reader :context
        # Returns the collection index for a `rule.each` evaluation.
        #
        # @return [Integer, nil]
        # @example Add an error for the second collection member
        #   rule(:tags).each { key.failure("is reserved") if index == 1 && value == "admin" }
        attr_reader :index
        # Returns failures collected while executing the rule.
        #
        # @return [Array<Message>]
        # @example Read failures after contract execution
        #   evaluator.failures # => [#<Dry::Validation::Rust::Message ...>]
        attr_reader :failures

        # Creates a rule evaluation context. This is primarily used by Contract.
        #
        # @api private
        #
        # @param contract [Contract] contract executing the rule
        # @param result [Contract::Result] result receiving rule failures
        # @param paths [Array<Array<Symbol, Integer>>] paths declared for the rule
        # @param context [Hash] mutable context for the current contract call
        # @param default_path [Array<Symbol, Integer>] path used by {#key} when omitted
        # @param index [Integer, nil] current `rule.each` collection index
        # @return [Evaluator]
        # @example Contract creates an evaluator while executing a rule
        #   contract.call(age: 17)
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
        #
        # @api private
        #
        # @param block [Proc, nil] rule block to execute
        # @param macro_calls [Array<Array>] macro calls declared for the rule
        # @param keyword_params [Array<Symbol>] evaluator values injected into the block
        # @return [Evaluator] this evaluator
        # @example Execute a rule with its declared macro calls
        #   evaluator.execute(rule.block, rule.macro_calls)
        def execute(block, macro_calls, keyword_params: [])
          execute_block(block, keyword_params) if block
          macro_calls.each { |call| execute_macro(call) }
          collect_failures
          self
        end

        # Returns the failure collector for a path, defaulting to the rule path.
        #
        # @param path [Symbol, String, Array, Hash] key or supported path specification
        # @return [Failures] collector that adds rule failures at the path
        # @example Add an error at the rule's default path
        #   rule(:email) { key.failure("is already taken") }
        # @example Add an error at a different path
        #   rule(:password) { key(:password_confirmation).failure("does not match") }
        def key(path = default_path)
          normalized = Path.parse(path)
          @key_failures[normalized] ||= Failures.new(normalized)
        end

        # Returns the failure collector for base-level messages.
        #
        # @return [Failures] collector that adds base-level rule failures
        # @example Add a contract-wide error
        #   rule { base.failure("cannot be approved") }
        def base
          @base_failures
        end

        # Returns the default rule path as a key or nested path.
        #
        # @return [Symbol, Array<Symbol, Integer>]
        # @example Read a single-key rule name
        #   rule(:email) { key_name # => :email }
        def key_name
          default_path.length == 1 ? default_path.first : default_path
        end

        # Returns the value at the rule's primary path, or nil when absent.
        #
        # @return [Object, nil]
        # @example Reject a value in a rule
        #   rule(:age) { key.failure("must be at least 18") if value < 18 }
        def value
          raw = Path.fetch(values.data, value_path)
          raw.equal?(Path::Undefined) ? nil : raw
        end

        # Returns whether validated output contains a key or path.
        #
        # @param name [Symbol, String, Array, Hash] key or supported path specification
        # @return [Boolean]
        # @example Require a related value
        #   rule(:password) { key.failure("needs confirmation") unless key?(:password_confirmation) }
        def key?(name = value_path)
          Path.key?(values.data, name)
        end

        # Returns whether the schema has an error at a path.
        #
        # @param path [Symbol, String, Array, Hash] key or supported path specification
        # @return [Boolean]
        # @example Skip a dependent check after a schema failure
        #   rule(:age) { key.failure("is too young") unless schema_error?(:age) || value >= 18 }
        def schema_error?(path)
          result.schema_error?(path)
        end

        # Alias for #schema_error?.
        #
        # @example Use the short schema-error predicate
        #   rule(:age) { key.failure("is too young") unless error?(:age) || value >= 18 }
        alias error? schema_error?

        # Returns whether a rule error exists at a path or the default path.
        #
        # @param path [Symbol, String, Array, Hash, nil] path to check, or the default rule path
        # @return [Boolean]
        # @example Avoid adding a duplicate rule error
        #   rule(:email) { key.failure("is blocked") unless rule_error? }
        def rule_error?(path = nil)
          if path
            result.rule_error?(path)
          else
            !key(default_path).empty?
          end
        end

        # Returns whether a base-level rule error exists.
        #
        # @return [Boolean]
        # @example Check whether this rule added a base failure
        #   rule { base.failure("cannot continue") unless base_rule_error? }
        def base_rule_error?
          !base.empty? || result.base_rule_error?
        end

        # Returns the mutable context supplied to the contract call.
        #
        # @return [Hash]
        # @example Access call context through the compatibility helper
        #   rule(:role) { _context[:actor] # => current actor }
        def _context
          context
        end

        # Reports contract methods delegated through this evaluator.
        #
        # @param name [Symbol] method name to check
        # @param include_private [Boolean] whether private methods are included
        # @return [Boolean]
        # @example Check a contract helper exposed in a rule
        #   evaluator.respond_to?(:reserved?) # => true
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
