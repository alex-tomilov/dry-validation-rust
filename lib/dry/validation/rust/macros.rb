# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      Macro = Struct.new(:name, :args, :block, keyword_init: true) do
        def with(call_args)
          self.class.new(name: name, args: args + call_args, block: block)
        end
      end

      class MacroRegistry
        def initialize(parent = nil)
          @parent = parent
          @entries = {}
        end

        def register(name, *args, &block)
          raise ArgumentError, "a macro block is required" unless block

          @entries[name.to_sym] = Macro.new(name: name.to_sym, args: args, block: block)
          self
        end

        def fetch(name)
          @entries.fetch(name.to_sym) { @parent&.fetch(name) || raise(KeyError, "unknown macro: #{name}") }
        end

        def key?(name)
          @entries.key?(name.to_sym) || @parent&.key?(name)
        end
      end
    end
  end
end
