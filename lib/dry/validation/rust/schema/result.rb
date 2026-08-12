# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        Result = Data.define(:output, :messages) do
          alias_method :to_h, :output

          def success?
            messages.empty?
          end

          def failure?
            !success?
          end

          def errors(options = {})
            MessageSet.new(messages, options).with(options)
          end

          def error?(spec)
            path = Path.parse(spec)
            messages.any? { |message| Path.prefix?(message.path, path) }
          end

          def [](key)
            output[key]
          end

          def key?(key)
            output.key?(key)
          end
        end
      end
    end
  end
end
