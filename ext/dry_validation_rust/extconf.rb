# frozen_string_literal: true

require "mkmf"

begin
  require "rb_sys/mkmf"
rescue LoadError
  local_rb_sys = ENV["RB_SYS_GEM_LIB"]
  if local_rb_sys && File.directory?(local_rb_sys)
    $LOAD_PATH.unshift(local_rb_sys)
    require "rb_sys/mkmf"
  else
    abort "rb_sys is required to build dry-validation-rust (gem install rb_sys)"
  end
end

create_rust_makefile("dry_validation_rust/native") do |config|
  config.profile = ENV.fetch("RB_SYS_CARGO_PROFILE", "release").to_sym
  config.ext_dir = "."
  config.env = {
    "BINDGEN_EXTRA_CLANG_ARGS" => "-include stdbool.h"
  }
  config.use_stable_api_compiled_fallback = true
end
