# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Contract
        class Values
          include Enumerable

          # @return [Hash] validated output data.
          attr_reader :data

          # Wraps validated output data for rule and result access.
          def initialize(data)
            @data = data
          end

          # Reads a value by key, path, or supported multi-path specification.
          def [](*args)
            return data.dig(*args) if args.length > 1

            spec = args.fetch(0)
            if spec.is_a?(Hash) && spec.values.first.is_a?(Array)
              head = spec.keys.first
              return spec.values.first.map { |tail| Path.fetch(data, [head, *Path.parse(tail)], nil) }
            end

            value = Path.fetch(data, spec)
            value.equal?(Path::Undefined) ? nil : value
          end

          # Returns whether data contains a key or path.
          def key?(key)
            Path.key?(data, key)
          end

          # Iterates through the underlying output Hash.
          def each(&)
            data.each(&)
          end

          # Fetches a value using Hash#fetch semantics.
          def fetch(*, &)
            data.fetch(*, &)
          end

          # Returns the underlying output Hash.
          def to_h
            data
          end

          # Supports Hash pattern matching against output data.
          def deconstruct_keys(keys)
            keys ? data.slice(*keys) : data
          end

          # Reports public Hash methods delegated to underlying data.
          def respond_to_missing?(name, include_private = false)
            data.respond_to?(name, include_private) || super
          end

          private

          def method_missing(name, ...)
            return data.public_send(name, ...) if data.respond_to?(name)

            super
          end
        end
      end
    end
  end
end
