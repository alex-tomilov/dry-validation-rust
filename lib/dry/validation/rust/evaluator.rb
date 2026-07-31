# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Evaluator
        attr_reader :contract, :result, :paths, :values, :context, :index, :failures

        def initialize(contract:, result:, paths:, default_path: paths.first || [], context:, index: nil)
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

        def execute(block, macro_calls, keyword_params: [])
          execute_block(block, keyword_params) if block
          macro_calls.each { |call| execute_macro(call) }
          collect_failures
          self
        end

        def key(path = default_path)
          normalized = Path.parse(path)
          @key_failures[normalized] ||= Failures.new(normalized)
        end

        def base
          @base_failures
        end

        def key_name
          default_path.length == 1 ? default_path.first : default_path
        end

        def value
          raw = Path.fetch(values.data, value_path)
          raw.equal?(Path::Undefined) ? nil : raw
        end

        def key?(name = value_path)
          Path.key?(values.data, name)
        end

        def schema_error?(path)
          result.schema_error?(path)
        end
        alias error? schema_error?

        def rule_error?(path = nil)
          if path
            result.rule_error?(path)
          else
            !key(default_path).empty?
          end
        end

        def base_rule_error?
          !base.empty? || result.base_rule_error?
        end

        def _context
          context
        end

        def respond_to_missing?(name, include_private = false)
          contract.respond_to?(name, true) || super
        end

        private

        def default_path
          @default_path
        end

        def value_path
          paths.first || []
        end

        def execute_block(block, keyword_params, macro: nil)
          keyword_values = {context: context, index: index, macro: macro}
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
          normalized = name.to_s.delete_suffix("?").to_sym
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
