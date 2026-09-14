# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Failures
        IDENTIFIER_MESSAGES = {
          acceptance: 'must be accepted',
          invalid: 'is invalid',
          taken: 'is already taken'
        }.freeze
        EMPTY_META = {}.freeze
        EMPTY_ARGS = [].freeze

        attr_reader :path, :messages

        def initialize(path = [])
          @path = Path.parse(path)
          @messages = []
        end

        def failure(message, tokens = EMPTY_META)
          if message.is_a?(String)
            add_message(interpolate(message, tokens), nil, EMPTY_META)
          else
            text, code, meta = normalize(message, tokens)
            add_message(text, code, meta)
          end
          self
        end

        def empty?
          messages.empty?
        end

        private

        def add_message(text, code, meta)
          messages << Message.new(
            text: text,
            path: path,
            code: code,
            meta: meta,
            source: :rule,
            args: EMPTY_ARGS
          )
        end

        def normalize(message, tokens)
          case message
          when String
            [interpolate(message, tokens), nil, EMPTY_META]
          when Symbol
            [
              interpolate(IDENTIFIER_MESSAGES.fetch(message, message.to_s.tr('_', ' ')), tokens),
              message,
              EMPTY_META
            ]
          when Hash
            raw_text = message.fetch(:text)
            text, code, = normalize(raw_text, tokens)
            [text, code, message.except(:text)]
          else
            [message.to_s, nil, EMPTY_META]
          end
        end

        def interpolate(text, tokens)
          return text if tokens.empty?

          text % tokens
        rescue KeyError
          text
        end
      end
    end
  end
end
