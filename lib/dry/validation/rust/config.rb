# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class MessageConfig
        attr_accessor :backend, :default_locale, :top_namespace, :load_paths

        def initialize
          @backend = :yaml
          @default_locale = :en
          @top_namespace = :dry_validation_rust
          @load_paths = []
        end

        def dup
          copy = super
          copy.load_paths = load_paths.dup
          copy
        end
      end

      class Config
        attr_reader :validate_keys
        attr_accessor :messages

        def initialize
          @validate_keys = false
          @messages = MessageConfig.new
        end

        def validate_keys=(value)
          @validate_keys = !!value
        end

        def dup
          copy = super
          copy.messages = messages.dup
          copy
        end
      end
    end
  end
end
