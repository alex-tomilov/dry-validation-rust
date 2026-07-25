# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Rule
        attr_reader :paths, :default_path, :block, :macro_calls

        def initialize(paths:, default_path: paths.first || [], block: nil)
          @paths = paths
          @default_path = default_path
          @block = block
          @macro_calls = []
          @each = false
        end

        def validate(*macros, &new_block)
          @block = new_block if new_block
          @macro_calls = parse_macros(macros)
          self
        end

        def each(*macros, &new_block)
          raise ArgumentError, "rule.each requires exactly one root key" unless paths.length == 1

          @each = true
          @block = new_block if new_block
          @macro_calls = parse_macros(macros)
          self
        end

        def each?
          @each
        end

        def inspect
          "#<#{self.class} paths=#{paths.inspect} each=#{each?}>"
        end

        private

        def parse_macros(specs)
          specs.flat_map do |spec|
            case spec
            when Hash
              spec.map { |name, args| [name.to_sym, *Array(args)] }
            else
              [[spec.to_sym]]
            end
          end
        end
      end
    end
  end
end
