# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # @api private
        class RubyTypeProcessor
          def self.apply(definitions, data, messages, message_backend)
            error_paths = messages.to_set(&:path)
            stack = [[:definitions, definitions, data, []]]

            until stack.empty?
              kind, *arguments = stack.pop
              case kind
              when :definitions
                current_definitions, current_data, prefix = arguments
                next unless current_data.is_a?(Hash)

                current_definitions.reverse_each do |field|
                  stack << [:field, field, current_data, prefix]
                end
              when :field
                field, current_data, prefix = arguments
                next unless current_data.key?(field.name)

                path = [*prefix, field.name]
                apply_to(field, current_data, path, messages, error_paths, message_backend)
                stack << [:definitions, field.children, current_data[field.name], path]
              end
            end
          end

          def self.apply_to(field, data, path, messages, error_paths, message_backend)
            return unless field.ruby_type && !error_paths.include?(path)

            result = field.ruby_type.try(data[field.name])
            data[field.name] = result.input
            return if result.success?

            messages << Message.new(
              text: message_backend.message(
                code: :type, predicate: nil, args: [], type: field.type, fallback: 'is invalid'
              ),
              path: path, code: :type, source: :schema
            )
            error_paths << path
          end

          private_class_method :apply_to
        end
      end
    end
  end
end
