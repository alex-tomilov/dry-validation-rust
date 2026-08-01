# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      # Normalizes the path forms accepted by dry-validation's public rule API.
      module Path
        module_function

        def parse(spec)
          case spec
          when nil then []
          when Symbol then [spec]
          when String then spec.split('.').map!(&:to_sym)
          when Array then spec.dup
          when Hash
            key, value = spec.first
            [key, *parse(value)]
          else
            raise ArgumentError, '+spec+ must be a Symbol, String, Array, or Hash'
          end
        end

        def expand(spec)
          return [parse(spec)] unless spec.is_a?(Hash)

          spec.flat_map do |key, value|
            if value.is_a?(Array)
              value.map { |child| [key, *parse(child)] }
            else
              [[key, *parse(value)]]
            end
          end
        end

        def fetch(data, path, undefined = Undefined)
          current = data
          parse(path).each do |key|
            if current.is_a?(Array) && key.is_a?(Integer)
              return undefined unless key >= 0 && key < current.length

              current = current[key]
            elsif current.respond_to?(:key?) && current.key?(key)
              current = current[key]
            else
              return undefined
            end
          end
          current
        end

        def key?(data, path)
          !fetch(data, path).equal?(Undefined)
        end

        def prefix?(candidate, prefix)
          candidate[0, prefix.length] == prefix
        end

        Undefined = Object.new.freeze
      end
    end
  end
end
