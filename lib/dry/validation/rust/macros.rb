# frozen_string_literal: true

require_relative "block_keyword_parameters"

module Dry
  module Validation
    module Rust
      Macro = Struct.new(:name, :args, :block, :keyword_params, keyword_init: true) do
        def with(call_args)
          self.class.new(name: name, args: args + call_args, block: block, keyword_params: keyword_params)
        end
      end

      class MacroRegistry
        def initialize(parent = nil)
          @parent = parent
          @entries = {}
        end

        def register(name, *args, &block)
          raise ArgumentError, "a macro block is required" unless block

          keyword_params = BlockKeywordParameters.extract(block)
          @entries[name.to_sym] = Macro.new(
            name: name.to_sym,
            args: args,
            block: block,
            keyword_params: keyword_params
          )
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
