# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # @api private
        class FieldBuilder
          attr_reader :definition, :mode

          def initialize(definition, mode:)
            @definition = definition
            @mode = mode
          end

          # Declares a typed value and optionally overrides inherited coercion strictness.
          #
          # @param strict [Boolean, nil] whether to disable literal coercion for this field.
          # @param lax [Boolean, nil] whether to enable literal coercion for this field.
          # @raise [ArgumentError] when strictness options conflict or are not booleans.
          def value(*specs, strict: nil, lax: nil, **predicates, &block)
            apply_strictness(strict, lax)
            apply_specs(specs, predicates)
            if block
              nested_value_block? ? nested_target(block) : PredicateBlock.new(definition).instance_eval(&block)
            end
            self
          end

          # Declares a typed value with literal coercion disabled for this field.
          #
          # @see #value
          def strict(*specs, **predicates, &)
            value(*specs, strict: true, **predicates, &)
          end

          # Declares a typed value with literal coercion enabled for this field.
          #
          # @see #value
          def lax(*specs, **predicates, &)
            value(*specs, lax: true, **predicates, &)
          end

          def filled(*specs, **predicates, &)
            definition.filled = true
            value(*specs, **predicates, &)
          end

          def maybe(*specs, **predicates, &)
            definition.nullable = true
            value(*specs, **predicates, &)
          end

          def hash(schema = nil, &block)
            definition.type = :hash
            nested = DSL.new(mode: mode)
            nested.import(schema) if schema
            nested.instance_eval(&block) if block
            definition.children = nested.fields
            self
          end

          def array(member_type = nil, **predicates, &block)
            definition.type = :array
            predicates.each { |name, argument| definition.add_predicate(name, argument: argument) }

            if member_type
              member = FieldDefinition.new(name: nil, required: true)
              if member_type.is_a?(Schema)
                member.type = :hash
                member.children = member_type.fields.map(&:deep_dup)
              elsif custom_type?(member_type)
                raise UnsupportedFeatureError,
                      'custom dry-types array members are not supported by the Ruby fallback yet'
              else
                assign_type(member, member_type)
              end
              definition.member = member
            end

            if block
              definition.member ||= FieldDefinition.new(name: nil, required: true)
              definition.member.type = :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.member.children = nested.fields
            end
            self
          end

          def each(member_type = nil, **predicates, &)
            array(member_type, **predicates, &)
          end

          def method_missing(name, *args, **kwargs, &block)
            if name.to_s.end_with?('?') && block.nil?
              argument = if kwargs.empty?
                           args.length <= 1 ? args.first : args
                         else
                           kwargs
                         end
              definition.add_predicate(name, argument: argument.nil? || argument)
              return self
            end

            super
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?('?') || super
          end

          private

          def apply_strictness(strict, lax)
            raise ArgumentError, 'strict and lax cannot both be specified' if !strict.nil? && !lax.nil?

            if !strict.nil?
              definition.strict = boolean_strictness!(:strict, strict)
            elsif !lax.nil?
              definition.strict = !boolean_strictness!(:lax, lax)
            end
          end

          def boolean_strictness!(name, value)
            return value if [true, false].include?(value)

            raise ArgumentError, "#{name} must be true or false"
          end

          def apply_specs(specs, predicates)
            remaining = specs.dup
            assign_type(definition, remaining.shift) if remaining.first && type_spec?(remaining.first)

            remaining.each do |predicate|
              case predicate
              when Symbol then definition.add_predicate(predicate)
              when Hash then predicate.each { |name, argument| definition.add_predicate(name, argument: argument) }
              else
                raise UnsupportedFeatureError,
                      "unsupported type or predicate specification: #{predicate.class.name}"
              end
            end
            predicates.each { |name, argument| definition.add_predicate(name, argument: argument) }
          end

          def type_spec?(spec)
            builtin_type?(spec) || custom_type?(spec)
          end

          def assign_type(target, type)
            if builtin_type?(type)
              target.type = type == :datetime ? :date_time : type
            elsif custom_type?(type)
              target.type = :any
              target.ruby_type = type
            else
              raise UnsupportedFeatureError,
                    "unsupported type or predicate specification: #{type.class.name}"
            end
          end

          def builtin_type?(type)
            type.is_a?(Symbol) && TYPES.include?(type)
          end

          def custom_type?(type)
            !type.is_a?(Symbol) && type.respond_to?(:try)
          end

          def nested_value_block?
            definition.type == :hash || (definition.type == :array && definition.member&.type == :hash)
          end

          def nested_target(block)
            if definition.type == :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.children = nested.fields
            else
              definition.member ||= FieldDefinition.new(name: nil, required: true)
              definition.member.type = :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.member.children = nested.fields
            end
          end
        end
      end
    end
  end
end
