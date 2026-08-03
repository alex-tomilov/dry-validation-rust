# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      module BlockKeywordParameters
        EMPTY = [].freeze

        module_function

        def extract(block)
          block.parameters.filter_map do |kind, name|
            name if %i[key keyreq].include?(kind)
          end.freeze
        end
      end
    end
  end
end
