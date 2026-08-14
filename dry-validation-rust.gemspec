# frozen_string_literal: true

require_relative 'lib/dry/validation/rust/version'

Gem::Specification.new do |spec|
  spec.name = 'dry-validation-rust'
  spec.version = Dry::Validation::Rust::VERSION
  spec.authors = ['Alexey Tomilov']

  spec.summary = 'Experimental Rust-backed validation contracts with a dry-validation-like API'
  spec.description = <<~DESCRIPTION
    A hybrid Ruby/Rust validation gem that compiles a documented subset of
    dry-validation's declarative schema DSL into a native Rust execution plan
    while retaining Ruby rule blocks and Ruby-owned dynamic behavior.
  DESCRIPTION
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'
  spec.homepage = 'https://github.com/alex-tomilov/dry-validation-rust'

  spec.files = [
    'CHANGELOG.md',
    'LICENSE',
    'NOTICE.md',
    'README.md',
    'dry-validation-rust.gemspec',
    'rust-toolchain.toml',
    'docs/ARCHITECTURE.md',
    'docs/COMPATIBILITY.md',
    'docs/FEASIBILITY.md',
    'docs/SUPPORT_MATRIX.md',
    'docs/VERIFICATION.md',
    Dir['lib/**/*.rb'],
    'ext/dry_validation_rust/Cargo.lock',
    'ext/dry_validation_rust/Cargo.toml',
    'ext/dry_validation_rust/extconf.rb',
    Dir['ext/dry_validation_rust/benches/**/*.rs'],
    Dir['ext/dry_validation_rust/src/**/*.rs']
  ].flatten.sort
  spec.require_paths = ['lib']
  spec.extensions = ['ext/dry_validation_rust/extconf.rb']
  spec.add_dependency 'bigdecimal', '>= 3.1', '< 5.0'
  spec.add_dependency 'rb_sys', '~> 0.9'
  spec.add_development_dependency 'memory_profiler', '~> 1.1'
  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'mutex_m', '~> 0.2'
  spec.add_development_dependency 'ostruct', '~> 0.6'
  spec.add_development_dependency 'rake', '~> 13.1'
  spec.add_development_dependency 'rake-compiler', '~> 1.3'
  spec.add_development_dependency 'rake-compiler-dock', '~> 1.12'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/alex-tomilov/dry-validation-rust'
  spec.metadata['changelog_uri'] = 'https://github.com/alex-tomilov/dry-validation-rust/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/alex-tomilov/dry-validation-rust/blob/main/README.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/alex-tomilov/dry-validation-rust/issues'
end
