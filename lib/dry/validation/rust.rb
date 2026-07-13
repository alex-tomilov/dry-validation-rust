# frozen_string_literal: true

require_relative "rust/version"
require_relative "rust/errors"
require_relative "rust/native"
require_relative "rust/path"
require_relative "rust/message"
require_relative "rust/message_set"
require_relative "rust/values"
require_relative "rust/macros"
require_relative "rust/failures"
require_relative "rust/config"
require_relative "rust/schema"
require_relative "rust/rule"
require_relative "rust/evaluator"
require_relative "rust/result"
require_relative "rust/contract"

module Dry
  module Validation
    module Rust
      class << self
        def global_macros
          @global_macros ||= MacroRegistry.new
        end

        def register_macro(name, *args, &block)
          global_macros.register(name, *args, &block)
          self
        end

        def Contract(options = {}, &block)
          Contract.build(options, &block)
        end

        def load_extensions(*names)
          names.each do |name|
            next if name.to_sym == :predicates_as_macros

            raise UnsupportedFeatureError,
              "extension #{name.inspect} is not implemented in the experimental Rust compatibility layer"
          end
          self
        end
      end

      register_macro(:acceptance) do
        key.failure(:acceptance) unless value.equal?(true)
      end
    end
  end
end
