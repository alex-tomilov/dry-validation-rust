# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        class PredicateBlock
          SINGLE_ARGUMENT_PREDICATES = %i[
            gt gteq lt lteq min_size max_size size format included_in excluded_from eql not_eql
          ].freeze
          ZERO_ARGUMENT_PREDICATES = %i[odd even].freeze

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
                  "unsupported predicate composition expression: #{name.inspect}"
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?('?') || super
          end

          private

          def validate_arity(name, args, kwargs)
            normalized_name = name.to_s.delete_suffix('?').to_sym
            argument_count = args.length + (kwargs.empty? ? 0 : 1)

            if SINGLE_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 1
              raise ArgumentError, "#{name} expects exactly one argument, got #{argument_count}"
            end

            return unless ZERO_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 0

            raise ArgumentError, "#{name} expects no arguments, got #{argument_count}"
          end
        end
      end
    end
  end
end
