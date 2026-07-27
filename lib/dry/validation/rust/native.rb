# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      module Native; end
    end
  end
end

begin
  require "dry_validation_rust/native"
rescue LoadError => packaged_error
  source_extension = File.expand_path("../../../../ext/dry_validation_rust/native", __dir__)
  begin
    require source_extension
  rescue LoadError
    raise LoadError, <<~MESSAGE
      dry-validation-rust could not load its native extension.
      Build it with `bundle exec rake compile` (source checkout) or reinstall the gem.
      Original error: #{packaged_error.message}
    MESSAGE
  end
end
