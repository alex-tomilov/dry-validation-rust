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

        attr_reader :path, :messages

        def initialize(path = [])
          @path = Path.parse(path)
          @messages = []
        end

        def failure(message, tokens = {})
          text, code, meta = normalize(message, tokens)
          messages << Message.new(text: text, path: path, code: code, meta: meta, source: :rule)
          self
        end

        def empty?
          messages.empty?
        end

        private

        def normalize(message, tokens)
          case message
          when String
            [interpolate(message, tokens), nil, {}]
          when Symbol
            [interpolate(IDENTIFIER_MESSAGES.fetch(message, message.to_s.tr('_', ' ')), tokens), message, {}]
          when Hash
            raw_text = message.fetch(:text)
            text, code, = normalize(raw_text, tokens)
            [text, code, message.except(:text)]
          else
            [message.to_s, nil, {}]
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
