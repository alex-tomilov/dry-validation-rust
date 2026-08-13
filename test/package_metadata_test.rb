# frozen_string_literal: true

require_relative 'test_helper'

class PackageMetadataTest < Minitest::Test
  def test_gemspec_has_public_project_metadata
    assert_equal 'https://github.com/alex-tomilov/dry-validation-rust', spec.homepage
    refute_match(/private experimental gem/i, spec.description)

    assert_equal 'true', spec.metadata.fetch('rubygems_mfa_required')
    assert_equal 'https://github.com/alex-tomilov/dry-validation-rust', spec.metadata.fetch('source_code_uri')
    assert_equal 'https://github.com/alex-tomilov/dry-validation-rust/blob/main/CHANGELOG.md',
                 spec.metadata.fetch('changelog_uri')
    assert_equal 'https://github.com/alex-tomilov/dry-validation-rust/blob/main/README.md',
                 spec.metadata.fetch('documentation_uri')
    assert_equal 'https://github.com/alex-tomilov/dry-validation-rust/issues', spec.metadata.fetch('bug_tracker_uri')
    refute spec.metadata.key?('funding_uri')
  end

  def test_source_gem_manifest_keeps_runtime_and_notice_files
    required = %w[
      CHANGELOG.md
      LICENSE
      NOTICE.md
      README.md
      docs/ARCHITECTURE.md
      docs/COMPATIBILITY.md
      docs/FEASIBILITY.md
      docs/SUPPORT_MATRIX.md
      docs/VERIFICATION.md
      dry-validation-rust.gemspec
      ext/dry_validation_rust/Cargo.lock
      ext/dry_validation_rust/Cargo.toml
      ext/dry_validation_rust/extconf.rb
      ext/dry_validation_rust/src/lib.rs
      lib/dry/validation/rust.rb
      lib/dry/validation/rust/contract.rb
      lib/dry/validation/rust/native.rb
      lib/dry/validation/rust/version.rb
      rust-toolchain.toml
    ]

    assert_empty required - spec.files
  end

  def test_source_gem_manifest_excludes_local_and_non_runtime_material
    forbidden_patterns = [
      %r{\Abenchmark/},
      %r{\Aexamples/},
      %r{\Adocs/codex/},
      %r{\Aext/dry_validation_rust/target/},
      %r{\Aext/dry_validation_rust/(?:Makefile|mkmf\.log|native\.)},
      %r{\A(?:pkg|coverage|\.bundle|\.ruby-lsp)/},
      /\.gem\z/
    ]

    forbidden_patterns.each do |pattern|
      assert_empty spec.files.grep(pattern), "unexpected package files matched #{pattern.inspect}"
    end
  end

  def test_extension_config_installs_p0_cross_compilation_targets
    extension_config = File.read(File.join(PROJECT_ROOT, 'ext/dry_validation_rust/extconf.rb'))

    %w[
      aarch64-unknown-linux-gnu
      x86_64-apple-darwin
      aarch64-apple-darwin
    ].each do |target|
      assert_includes extension_config, target
    end
  end

  private

  def spec
    @spec ||= Gem::Specification.load(File.join(PROJECT_ROOT, 'dry-validation-rust.gemspec'))
  end
end
