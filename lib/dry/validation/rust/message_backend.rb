# frozen_string_literal: true

require 'yaml'

module Dry
  module Validation
    module Rust
      # Adapter interface for resolving localized schema error messages.
      #
      # Custom backends must inherit from this class and implement {#message}.
      class MessageBackend
        # Creates a backend using the schema message configuration.
        #
        # @param config [MessageConfig] the configured message settings.
        def initialize(config); end

        # Resolves text for a schema error.
        #
        # @param code [Symbol] the error code.
        # @param predicate [Symbol, nil] the predicate name, without or with a trailing +?+.
        # @param args [Array] predicate arguments.
        # @param type [Symbol, nil] the normalized field type.
        # @param fallback [String] message used when no translation is available.
        # @return [String] the error message text.
        def message(code:, predicate:, args:, type:, fallback:)
          raise NotImplementedError, "#{self.class} must implement #message"
        end

        private

        def tokens_for(args, type)
          argument = args.first
          return range_tokens(argument, type) if argument.is_a?(Range)

          { num: argument, size: argument, left: argument, list: Array(argument).join(', '), type: type }
        end

        def range_tokens(argument, type)
          {
            num: argument.begin, size: argument, left: argument.begin, right: argument.end,
            list: "#{argument.begin} to #{argument.end}", type: type
          }
        end
      end

      # Resolves messages from YAML translation files listed in {MessageConfig#load_paths}.
      class YamlBackend < MessageBackend
        def initialize(config)
          super
          @default_locale = config.default_locale.to_sym
          @top_namespace = config.top_namespace.to_s
          @translations = load_yaml(config.load_paths)
        end

        def message(code:, predicate:, args:, type:, fallback:)
          key = predicate ? "#{predicate.to_s.delete_suffix('?')}?" : code.to_s
          template = @translations[[@default_locale, *@top_namespace.split('.'), 'errors', key].join('.')]
          template ? interpolate(template, tokens_for(args, type)) : fallback
        end

        private

        def load_yaml(paths)
          paths.each_with_object({}) do |path, translations|
            flatten(YAML.safe_load_file(path, aliases: false), [], translations)
          end
        end

        def flatten(value, path, translations)
          if value.is_a?(Hash)
            value.each { |key, child| flatten(child, [*path, key.to_s], translations) }
          elsif value.is_a?(String)
            translations[path.join('.')] = value
          end
        end

        def interpolate(template, tokens)
          template % tokens
        rescue KeyError => e
          raise ArgumentError, "message template is missing an interpolation token: #{e.message}"
        end
      end

      # Resolves messages through the optional i18n gem.
      class I18nBackend < MessageBackend
        def initialize(config)
          super
          @default_locale = config.default_locale.to_sym
          @top_namespace = config.top_namespace.to_s
          load_i18n(config.load_paths)
        end

        def message(code:, predicate:, args:, type:, fallback:)
          key = predicate ? "#{predicate.to_s.delete_suffix('?')}?" : code.to_s
          translation_key = [*@top_namespace.split('.'), 'errors', key].join('.')
          return fallback unless ::I18n.exists?(translation_key, @default_locale)

          ::I18n.t(translation_key, locale: @default_locale, **tokens_for(args, type))
        end

        private

        def load_i18n(paths)
          require 'i18n'
          paths.each do |path|
            data = YAML.safe_load_file(path, aliases: false)
            data.each { |locale, translations| ::I18n.backend.store_translations(locale, translations) }
          end
        rescue LoadError
          raise LoadError, 'the i18n gem is required for config.messages.backend = :i18n'
        end
      end
    end
  end
end
