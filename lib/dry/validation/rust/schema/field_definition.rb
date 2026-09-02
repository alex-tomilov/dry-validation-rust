# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # @api private
        class FieldDefinition
          attr_accessor :name, :required, :nullable, :filled, :type, :member, :ruby_type
          attr_reader :children, :predicates

          def initialize(name:, required:)
            @name = name&.to_sym
            @required = required
            @nullable = false
            @filled = false
            @type = :any
            @member = nil
            @ruby_type = nil
            @children = []
            @children_by_name = {}
            @predicates = []
          end

          def children=(children)
            @children = children
            @children_by_name = children.to_h { |child| [child.name, child] }
          end

          def child_at(name)
            @children_by_name[name.to_sym]
          end

          def add_predicate(name, argument: true)
            normalized_name = name.to_s.delete_suffix('?').to_sym
            unless (NATIVE_PREDICATES | RUBY_PREDICATES).include?(normalized_name)
              raise UnsupportedFeatureError,
                    "predicate #{normalized_name.inspect} is not supported; " \
                    'use a supported predicate or a contract rule. ' \
                    'See: https://github.com/alex-tomilov/dry-validation-rust/blob/main/docs/MIGRATION_RECIPES.md#uuid-and-other-dry-logic-predicates'
            end

            predicates << Predicate.new(name: normalized_name, argument: argument)
          end

          def to_native_h
            {
              name: name&.to_s,
              required: required,
              nullable: nullable,
              filled: filled,
              type: normalized_type.to_s,
              member: member&.to_native_h,
              children: children.map(&:to_native_h),
              predicates: predicates.filter_map do |predicate|
                next unless NATIVE_PREDICATES.include?(predicate.name)

                { name: predicate.name.to_s, argument: predicate.argument }
              end
            }
          end

          def normalized_type
            type == :datetime ? :date_time : type
          end

          def deep_dup
            self.class.new(name: name, required: required).tap do |copy|
              copy.nullable = nullable
              copy.filled = filled
              copy.type = type
              copy.ruby_type = ruby_type
              copy.member = member&.deep_dup
              copy.children = children.map(&:deep_dup)
              predicates.each do |predicate|
                copy.predicates << predicate.with(argument: duplicate_value(predicate.argument))
              end
            end
          end

          private

          def duplicate_value(value)
            case value
            when Array
              value.map { |item| duplicate_value(item) }
            when Hash
              value.each_with_object({}) do |(key, item), copy|
                copy[duplicate_value(key)] = duplicate_value(item)
              end
            else
              value.dup
            end
          rescue TypeError
            value
          end
        end
      end
    end
  end
end
