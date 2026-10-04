# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # Detects and evaluates Ruby-owned predicates against native schema output.
        # @api private
        module RubyPredicates
          private

          # @api private
          def ruby_predicates?(definitions)
            definitions.any? do |field|
              field.predicates.any? { |predicate| !NATIVE_PREDICATES.include?(predicate.name) } ||
                ruby_predicates?(field.children) ||
                (field.member && ruby_predicates?([field.member]))
            end
          end

          # @api private
          def apply_ruby_predicates(definitions, data, prefix, messages)
            error_paths = messages.to_set(&:path)
            apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
          end

          # @api private
          def apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
            stack = [[:definitions, definitions, data, prefix]]

            until stack.empty?
              kind, *arguments = stack.pop
              case kind
              when :definitions
                current_definitions, current_data, current_prefix = arguments
                next unless current_data.is_a?(Hash)

                current_definitions.reverse_each do |field|
                  stack << [:field, field, current_data, current_prefix]
                end
              when :field
                field, current_data, current_prefix = arguments
                next unless current_data.key?(field.name)

                path = [*current_prefix, field.name]
                value = current_data[field.name]
                apply_ruby_predicates_to(field, value, path, messages, error_paths)

                if value.is_a?(Hash)
                  stack << [:definitions, field.children, value, path]
                elsif value.is_a?(Array) && field.member
                  value.each_index.reverse_each do |index|
                    stack << [:member, field.member, value[index], [*path, index]]
                  end
                end
              when :member
                member, value, path = arguments
                apply_ruby_predicates_to(member, value, path, messages, error_paths)
                stack << [:definitions, member.children, value, path]
              end
            end
          end

          # @api private
          def apply_ruby_predicates_to(field, value, path, messages, error_paths)
            return if error_paths.include?(path)

            field.predicates.each do |predicate|
              next if NATIVE_PREDICATES.include?(predicate.name)

              unless predicate_valid?(predicate, value)
                messages << predicate_message(predicate, path)
                error_paths << path
              end
            end
          end

          # @api private
          def predicate_valid?(predicate, value)
            case predicate.name
            when :format then value.respond_to?(:match?) && predicate.argument.match?(value)
            when :included_in then predicate.argument.include?(value)
            when :excluded_from then !predicate.argument.include?(value)
            when :eql then value.eql?(predicate.argument)
            when :not_eql then !value.eql?(predicate.argument)
            else
              raise UnsupportedFeatureError,
                    "predicate #{predicate.name.inspect} is not supported natively; move it to a contract rule"
            end
          end

          # @api private
          def predicate_message(predicate, path)
            text = case predicate.name
                   when :format then 'is in invalid format'
                   when :included_in then "must be one of: #{Array(predicate.argument).join(', ')}"
                   when :excluded_from then "must not be one of: #{Array(predicate.argument).join(', ')}"
                   when :eql then "must be equal to #{predicate.argument}"
                   when :not_eql then "must not be equal to #{predicate.argument}"
                   else 'is invalid'
                   end
            text = @message_backend.message(
              code: predicate.name, predicate: predicate.name, args: [predicate.argument], type: nil, fallback: text
            )
            Message.new(
              text: text, path: path, code: predicate.name, source: :schema,
              predicate: "#{predicate.name}?", args: [predicate.argument]
            )
          end
        end
      end
    end
  end
end
