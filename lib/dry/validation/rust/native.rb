# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      # @api private
      module Native; end
    end
  end
end

begin
  require 'dry_validation_rust/native'
rescue LoadError => e
  source_extension = File.expand_path('../../../../ext/dry_validation_rust/native', __dir__)
  begin
    require source_extension
  rescue LoadError
    raise LoadError, <<~MESSAGE
      dry-validation-rust could not load its native extension.
      Build it with `bundle exec rake compile` (source checkout) or reinstall the gem.
      Original error: #{e.message}
    MESSAGE
  end
end
