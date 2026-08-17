# frozen_string_literal: true

require 'set'

module Dry
  module Validation
    module Rust
      class Schema
        Result = Data.define(:output, :messages, :error_prefixes) do
          class << self
            alias_method :build, :new
            private :build

            # Creates a structural validation result and caches the schema-error path prefixes.
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
              prefixes = messages.each_with_object(Set.new) do |message, set|
                path = message.path
                (0..path.length).each { |length| set << path.take(length) }
              end.freeze

              build(output, messages, prefixes)
            end
          end

          # Returns the immutable set of every prefix of a schema-error path.
          #
          # @return [Set<Array>] cached schema-error path prefixes

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
