# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # @api private
        class PredicateBlock
          ARITY_MAP = {
            gt: 1, gteq: 1, lt: 1, lteq: 1, min_size: 1, max_size: 1, size: 1,
            format: 1, included_in: 1, excluded_from: 1, eql: 1, not_eql: 1,
            odd: 0, even: 0
          }.freeze

          def initialize(definition)
            @definition = definition
          end

          def method_missing(name, *args, **kwargs, &block)
            if name.to_s.end_with?('?') && block.nil?
              validate_arity(name, args, kwargs)
              argument = if kwargs.empty?
                           args.length <= 1 ? args.first : args
                         else
                           kwargs
                         end
              @definition.add_predicate(name, argument: argument.nil? || argument)
              return self
            end

            raise UnsupportedFeatureError,
                  'boolean predicate AST composition is not supported; use sequential predicates. ' \
                  'See: https://github.com/alex-tomilov/dry-validation-rust/blob/main/docs/MIGRATION_RECIPES.md#boolean-predicate-composition'
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?('?') || super
          end

          private

          def validate_arity(name, args, kwargs)
            normalized_name = name.to_s.delete_suffix('?').to_sym
            expected = ARITY_MAP[normalized_name]
            return unless expected

            argument_count = args.length + (kwargs.empty? ? 0 : 1)
            return if argument_count == expected

            article = expected == 1 ? 'exactly one argument' : 'no arguments'
            raise ArgumentError, "#{name} expects #{article}, got #{argument_count}"
          end
        end
      end
    end
  end
end
