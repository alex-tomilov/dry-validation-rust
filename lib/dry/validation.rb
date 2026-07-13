# frozen_string_literal: true

require_relative "validation/rust"

module Dry
  if const_defined?(:Schema, false) &&
      !(const_get(:Schema, false).const_defined?(:RUST_COMPATIBILITY_LAYER, false))
    raise LoadError, <<~MESSAGE
      dry-schema and dry-validation-rust cannot both own Dry::Schema in exact compatibility mode.
      Remove the upstream dry-schema/dry-validation gems, or use the side-by-side
      dry/validation/rust namespace.
    MESSAGE
  end

  unless const_defined?(:Schema, false)
    module Schema
      RUST_COMPATIBILITY_LAYER = true
      VERSION = Validation::Rust::VERSION

      class << self
        def Params(*external_schemas, &block)
          Validation::Rust::Schema.Params(*external_schemas, &block)
        end

        def JSON(*external_schemas, &block)
          Validation::Rust::Schema.JSON(*external_schemas, &block)
        end

        def define(*external_schemas, &block)
          Validation::Rust::Schema.define(:schema, *external_schemas, &block)
        end
      end
    end
  end

  module Validation
    if const_defined?(:Contract, false) && const_get(:Contract, false) != Rust::Contract
      raise LoadError, <<~MESSAGE
        dry-validation and dry-validation-rust cannot both own Dry::Validation::Contract.
        Remove the upstream dry-validation gem when using exact compatibility mode, or
        require "dry/validation/rust" and inherit from Dry::Validation::Rust::Contract.
      MESSAGE
    end

    Contract = Rust::Contract unless const_defined?(:Contract, false)
    Result = Rust::Result unless const_defined?(:Result, false)
    Message = Rust::Message unless const_defined?(:Message, false)
    MessageSet = Rust::MessageSet unless const_defined?(:MessageSet, false)
    Evaluator = Rust::Evaluator unless const_defined?(:Evaluator, false)
    VERSION = Rust::VERSION unless const_defined?(:VERSION, false)

    class << self
      def Contract(options = {}, &block)
        Rust.Contract(options, &block)
      end

      def register_macro(name, *args, &block)
        Rust.register_macro(name, *args, &block)
      end

      def load_extensions(*names)
        Rust.load_extensions(*names)
      end
    end
  end
end
