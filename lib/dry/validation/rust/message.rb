# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Message
        attr_reader :text, :path, :meta, :code, :source, :predicate, :args

        def initialize(text, path:, meta: {}, code: nil, source: :rule, predicate: nil, args: [])
          @text = text.to_s.freeze
          @path = Array(path).freeze
          @meta = meta.freeze
          @code = code&.to_sym
          @source = source
          @predicate = predicate&.to_sym
          @args = args.freeze
        end

        def base?
          path.compact.empty?
        end

        def schema?
          source == :schema
        end

        def rule?
          source == :rule
        end

        def payload
          meta.empty? ? text : { text: text, **meta }
        end

        def with_text(new_text)
          self.class.new(
            new_text, path: path, meta: meta, code: code, source: source,
                      predicate: predicate, args: args
          )
        end

        def to_s
          text
        end

        def ==(other)
          other.is_a?(Message) && [text, path, meta, code, source] ==
            [other.text, other.path, other.meta, other.code, other.source]
        end
      end
    end
  end
end
