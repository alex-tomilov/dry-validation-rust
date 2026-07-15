# frozen_string_literal: true

require_relative "lib/dry/validation/rust/version"

Gem::Specification.new do |spec|
  spec.name = "dry-validation-rust"
  spec.version = Dry::Validation::Rust::VERSION
  spec.authors = ["Alexey Tomilov"]

  spec.summary = "Experimental Rust-backed validation contracts with a dry-validation-like API"
  spec.description = <<~DESCRIPTION
    A private experimental gem that compiles a compatible subset of dry-validation's
    declarative schema DSL into a native Rust execution plan while retaining Ruby rule blocks.
  DESCRIPTION
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir[
    "CHANGELOG.md", "LICENSE", "NOTICE.md", "README.md",
    "docs/**/*.md", "examples/**/*.rb", "benchmark/**/*.rb",
    "lib/**/*.rb", "ext/**/*.{rb,rs,toml,lock}"
  ].reject { |path| path.start_with?("ext/dry_validation_rust/target/") }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/dry_validation_rust/extconf.rb"]
  spec.add_runtime_dependency "bigdecimal", "~> 3.1"
  spec.add_runtime_dependency "rb_sys", "~> 0.9"
  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "mutex_m", "~> 0.2"
  spec.add_development_dependency "rake", "~> 13.1"

  spec.metadata["rubygems_mfa_required"] = "true"
end
