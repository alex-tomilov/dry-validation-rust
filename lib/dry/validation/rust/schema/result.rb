# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
        Result = Data.define(:output, :messages, :error_prefixes) do
          class << self
            alias_method :build, :new
            private :build

            # Creates a structural validation result and caches its schema-error path index.
            #
            # @param output [Hash] coerced schema output
            # @param messages [Array<Message>] schema validation failures
            # @return [Result] immutable schema validation result
            def new(output = nil, messages = nil, **kwargs)
              unknown = kwargs.keys - %i[output messages]
              unless unknown.empty?
                raise ArgumentError,
                      "unknown keyword#{'s' if unknown.length > 1}: #{unknown.map(&:inspect).join(', ')}"
              end

              output = kwargs.fetch(:output) if kwargs.key?(:output)
              messages = kwargs.fetch(:messages) if kwargs.key?(:messages)
              prefixes = PathTrie.new
              messages.each { |message| prefixes.add(message.path) }

              build(output, messages, prefixes.freeze)
            end
          end

          # Returns the immutable schema-error path index.
          #
          # @return [PathTrie] cached schema-error path index

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
