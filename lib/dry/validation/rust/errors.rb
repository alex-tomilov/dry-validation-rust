# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Error < StandardError; end
      class SchemaMissingError < Error; end
      class DuplicateSchemaError < Error; end
      class InvalidKeysError < Error; end
      class UnsupportedFeatureError < Error; end
      class NativeExtensionError < Error; end
    end
  end
end
