# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        # @api private
        class RubyTypeProcessor
          def self.apply(definitions, data, messages, message_backend)
            error_paths = messages.to_set(&:path)
            apply_at(definitions, data, [], messages, error_paths, message_backend)
          end

          def self.apply_at(definitions, data, prefix, messages, error_paths, message_backend)
            return unless data.is_a?(Hash)

            definitions.each do |field|
              next unless data.key?(field.name)

              path = [*prefix, field.name]
              if field.ruby_type && !error_paths.include?(path)
                result = field.ruby_type.try(data[field.name])
                data[field.name] = result.input
                unless result.success?
                  messages << Message.new(
                    text: message_backend.message(
                      code: :type, predicate: nil, args: [], type: field.type, fallback: 'is invalid'
                    ),
                    path: path, code: :type, source: :schema
                  )
                  error_paths << path
                end
              end

              apply_at(field.children, data[field.name], path, messages, error_paths, message_backend)
            end
          end

          private_class_method :apply_at
        end
      end
    end
  end
end
