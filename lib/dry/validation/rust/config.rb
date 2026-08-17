# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class MessageConfig
        BACKENDS = { yaml: YamlBackend, i18n: I18nBackend }.freeze

        attr_reader :backend
        attr_accessor :default_locale, :top_namespace, :load_paths

        def initialize
          self.backend = :yaml
          @default_locale = :en
          @top_namespace = :dry_validation
          @load_paths = []
        end

        # Selects a built-in backend or a custom {MessageBackend} subclass.
        #
        # @param backend [:yaml, :i18n, Class] backend identifier or adapter class.
        # @raise [ArgumentError] if the backend is unsupported.
        def backend=(backend)
          @backend = BACKENDS.fetch(backend) { validate_backend_class(backend) }
        rescue KeyError
          raise ArgumentError, backend_error(backend)
        end

        def dup
          copy = super
          copy.load_paths = load_paths.dup
          copy
        end

        private

        def validate_backend_class(backend)
          return backend if backend.is_a?(Class) && backend < MessageBackend

          raise ArgumentError, backend_error(backend)
        end

        def backend_error(backend)
          "messages.backend must be :yaml, :i18n, or a MessageBackend subclass; got #{backend.inspect}"
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
