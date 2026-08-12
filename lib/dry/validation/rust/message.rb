# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      Message = Data.define(:text, :path, :meta, :code, :source, :predicate, :args) do
        def initialize(text:, path:, meta: {}, code: nil, source: :rule, predicate: nil, args: [])
          super(
            text: text.to_s.freeze,
            path: Array(path).freeze,
            meta: meta.freeze,
            code: code&.to_sym,
            source: source,
            predicate: predicate&.to_sym,
            args: args.freeze
          )
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

        def to_s
          text
        end
      end
    end
  end
end
