# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Values
        include Enumerable

        attr_reader :data

        def initialize(data)
          @data = data
        end

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

        def key?(key)
          Path.key?(data, key)
        end

        def each(&)
          data.each(&)
        end

        def fetch(*, &)
          data.fetch(*, &)
        end

        def to_h
          data
        end

        def deconstruct_keys(keys)
          keys ? data.slice(*keys) : data
        end

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
