# frozen_string_literal: true

require 'mkmf'

begin
  require 'rb_sys/mkmf'
rescue LoadError
  local_rb_sys = ENV.fetch('RB_SYS_GEM_LIB', nil)
  if local_rb_sys && File.directory?(local_rb_sys)
    $LOAD_PATH.unshift(local_rb_sys)
    require 'rb_sys/mkmf'
  else
    abort 'rb_sys is required to build dry-validation-rust (gem install rb_sys)'
  end
end

ENV['RUSTUP_TOOLCHAIN'] ||= '1.75.0-x86_64-pc-windows-gnu' if RUBY_PLATFORM.include?('mingw')

create_rust_makefile('dry_validation_rust/native') do |config|
  config.profile = ENV.fetch('RB_SYS_CARGO_PROFILE', 'release').to_sym
  config.ext_dir = '.'
  config.env = {
    'BINDGEN_EXTRA_CLANG_ARGS' => '-include stdbool.h'
  }
  config.env['RUSTUP_TOOLCHAIN'] = ENV.fetch('RUSTUP_TOOLCHAIN') if ENV.key?('RUSTUP_TOOLCHAIN')
  config.extra_rustup_targets = %w[
    aarch64-unknown-linux-gnu
    x86_64-apple-darwin
    aarch64-apple-darwin
  ]
  config.use_stable_api_compiled_fallback = true
end
