# frozen_string_literal: true

require 'yaml'

module Dry
  module Validation
    module Rust
      class MessageConfig
        attr_accessor :backend, :default_locale, :top_namespace, :load_paths

        def initialize
          @backend = :yaml
          @default_locale = :en
          @top_namespace = :dry_validation
          @load_paths = []
        end

        def dup
          copy = super
          copy.load_paths = load_paths.dup
          copy
        end
      end

      # Resolves schema error text from the configured localized-message source.
      # @api private
      class MessageBackend
        def initialize(config)
          @backend = config.backend.to_sym
          @default_locale = config.default_locale.to_sym
          @top_namespace = config.top_namespace.to_s
          @translations = load_yaml(config.load_paths) if @backend == :yaml
          load_i18n(config.load_paths) if @backend == :i18n

          return if %i[yaml i18n].include?(@backend)

          raise ArgumentError, "+#{@backend}+ is not a valid messages identifier"
        end

        def message(code:, fallback:, predicate: nil, args: [], type: nil)
          key = predicate ? "#{predicate}?" : code.to_s
          tokens = tokens_for(args, type)
          template = translation_for(key, tokens)
          return fallback unless template

          @backend == :i18n ? template : interpolate(template, tokens)
        end

        private

        def translation_for(key, tokens)
          case @backend
          when :yaml then @translations[[@default_locale, *@top_namespace.split('.'), 'errors', key].join('.')]
          when :i18n then i18n_translation(key, tokens)
          end
        end

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

        def load_i18n(paths)
          require 'i18n'

          paths.each do |path|
            data = YAML.safe_load_file(path, aliases: false)
            data.each { |locale, translations| ::I18n.backend.store_translations(locale, translations) }
          end
        rescue LoadError
          raise LoadError, 'the i18n gem is required for config.messages.backend = :i18n'
        end

        def i18n_translation(key, tokens)
          translation_key = [*@top_namespace.split('.'), 'errors', key].join('.')
          return unless ::I18n.exists?(translation_key, @default_locale)

          ::I18n.t(translation_key, locale: @default_locale, **tokens)
        end

        def interpolate(template, tokens)
          template % tokens
        rescue KeyError => e
          raise ArgumentError, "message template is missing an interpolation token: #{e.message}"
        end

        def tokens_for(args, type)
          argument = args.first

          if argument.is_a?(Range)
            return {
              num: argument.begin,
              size: argument,
              left: argument.begin,
              right: argument.end,
              list: "#{argument.begin} to #{argument.end}",
              type: type
            }
          end

          {
            num: argument,
            size: argument,
            left: argument,
            list: Array(argument).join(', '),
            type: type
          }
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
