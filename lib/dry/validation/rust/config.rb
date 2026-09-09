# frozen_string_literal: true

require 'tmpdir'

module Dry
  module Validation
    module Rust
      # Configures the message backend used by compiled schemas.
      class MessageConfig
        BACKENDS = { yaml: YamlBackend, i18n: I18nBackend }.freeze

        # @return [:yaml, :i18n, Class] the selected built-in identifier or custom backend class.
        attr_reader :backend
        attr_accessor :default_locale, :top_namespace, :load_paths

        def initialize
          @backend = :yaml
          @default_locale = :en
          @top_namespace = :dry_validation
          @load_paths = []
        end

        # Selects a built-in backend or a custom {MessageBackend} subclass.
        #
        # @param backend [:yaml, :i18n, Class] backend identifier or adapter class.
        # @raise [ArgumentError] if the backend is unsupported.
        def backend=(backend)
          @backend = BACKENDS.key?(backend) ? backend : validate_backend_class(backend)
        end

        def dup
          copy = super
          copy.load_paths = load_paths.dup
          copy
        end

        # @api private
        def backend_class
          BACKENDS.fetch(backend, backend)
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
        # @return [Boolean] whether unknown keys are validation errors.
        # @return [Boolean] whether compiled native schema plans use disk caching.
        attr_reader :validate_keys, :plan_cache_enabled
        # @return [MessageConfig] message settings used by compiled schemas.
        attr_accessor :messages
        # @return [String] directory used to persist compiled native schema plans.
        attr_reader :plan_cache_dir

        def initialize
          @validate_keys = false
          @messages = MessageConfig.new
          @plan_cache_dir = default_plan_cache_dir
          @plan_cache_enabled = true
        end

        def validate_keys=(value)
          @validate_keys = !!value
        end

        # Enables or disables on-disk reuse of compiled native schema plans.
        #
        # @param value [Boolean] whether schemas use the configured plan cache.
        # @return [Boolean] the normalized setting.
        def plan_cache_enabled=(value)
          @plan_cache_enabled = !!value
        end

        # Changes the directory used to persist compiled native schema plans.
        #
        # @param value [#to_s] non-empty filesystem path.
        # @raise [ArgumentError] if the path is empty.
        def plan_cache_dir=(value)
          path = value.to_s
          raise ArgumentError, 'plan_cache_dir must not be empty' if path.empty?

          @plan_cache_dir = path
        end

        def dup
          copy = super
          copy.messages = messages.dup
          copy.plan_cache_dir = plan_cache_dir.dup
          copy
        end

        private

        def default_plan_cache_dir
          if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
            return Rails.root.join('tmp', 'dry_validation_plans').to_s
          end

          Dir.tmpdir
        end
      end
    end
  end
end
