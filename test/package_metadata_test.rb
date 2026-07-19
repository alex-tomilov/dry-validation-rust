# frozen_string_literal: true

require_relative "test_helper"

class PackageMetadataTest < Minitest::Test
  def test_gemspec_has_public_project_metadata
    assert_equal "https://github.com/alex-tomilov/dry-validation-rust", spec.homepage
    refute_match(/private experimental gem/i, spec.description)

    assert_equal "true", spec.metadata.fetch("rubygems_mfa_required")
    assert_equal "https://github.com/alex-tomilov/dry-validation-rust", spec.metadata.fetch("source_code_uri")
    assert_equal "https://github.com/alex-tomilov/dry-validation-rust/blob/main/CHANGELOG.md", spec.metadata.fetch("changelog_uri")
    assert_equal "https://github.com/alex-tomilov/dry-validation-rust/blob/main/README.md", spec.metadata.fetch("documentation_uri")
    assert_equal "https://github.com/alex-tomilov/dry-validation-rust/issues", spec.metadata.fetch("bug_tracker_uri")
    refute spec.metadata.key?("funding_uri")
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

  def test_package_audit_exposes_rb_sys_to_native_extension_build
    rakefile = File.read(File.join(PROJECT_ROOT, "Rakefile"))

    assert_includes rakefile, 'Gem::Specification.find_by_name("rb_sys")'
    assert_includes rakefile, '"RB_SYS_GEM_LIB" => rb_sys_gem_lib_path'
  end

  def test_package_audit_canonicalizes_installed_gem_path
    rakefile = File.read(File.join(PROJECT_ROOT, "Rakefile"))

    assert_includes rakefile, "loaded_path = File.realpath(loaded.full_gem_path)"
    assert_includes rakefile, "expected_path = File.realpath(gem_home)"
    assert_includes rakefile, 'loaded_path.start_with?("#{expected_path}#{File::SEPARATOR}")'
  end

  def test_development_dependencies_include_extracted_standard_libraries_for_ruby_35
    development_dependencies = spec.development_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] }
    lockfile = File.read(File.join(PROJECT_ROOT, "Gemfile.lock"))

    assert_equal "~> 0.3", development_dependencies.fetch("benchmark")
    assert_includes lockfile, "benchmark (0.3.0)"
    assert_includes lockfile, "benchmark (~> 0.3)"
    assert_equal "~> 0.6", development_dependencies.fetch("ostruct")
    assert_includes lockfile, "ostruct (0.6.0)"
    assert_includes lockfile, "ostruct (~> 0.6)"
  end

  private

  def spec
    @spec ||= Gem::Specification.load(File.join(PROJECT_ROOT, "dry-validation-rust.gemspec"))
  end
end
