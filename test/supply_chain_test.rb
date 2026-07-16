# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class SupplyChainTest < Minitest::Test
  def test_dependabot_covers_bundler_cargo_and_github_actions
    config = YAML.safe_load_file(File.join(PROJECT_ROOT, ".github", "dependabot.yml"))
    updates = config.fetch("updates")

    ecosystems = updates.map { |entry| [entry.fetch("package-ecosystem"), entry.fetch("directory")] }
    assert_includes ecosystems, ["bundler", "/"]
    assert_includes ecosystems, ["cargo", "/ext/dry_validation_rust"]
    assert_includes ecosystems, ["github-actions", "/"]

    updates.each do |entry|
      assert_equal "weekly", entry.fetch("schedule").fetch("interval")
      assert_operator entry.fetch("open-pull-requests-limit"), :<=, 5
    end
  end

  def test_native_bridge_updates_are_isolated
    config = YAML.safe_load_file(File.join(PROJECT_ROOT, ".github", "dependabot.yml"))

    bundler = dependabot_update(config, "bundler")
    cargo = dependabot_update(config, "cargo")

    assert_equal %w[rb_sys rake-compiler-dock], bundler.fetch("groups").fetch("ruby-native-bridge").fetch("patterns")
    assert_equal %w[magnus rb-sys], cargo.fetch("groups").fetch("rust-native-bridge").fetch("patterns")
  end

  def test_audit_policy_documents_exceptions_and_provenance
    policy = read_doc("docs/DEPENDENCY_SECURITY.md")

    assert_includes policy, "There are no active audit exceptions."
    assert_includes policy, "Expires: YYYY-MM-DD"
    assert_includes policy, "RubyGems trusted publishing"
    assert_includes policy, "avoid long-lived RubyGems tokens"
  end

  def test_security_workflow_has_audits_without_publish_credentials
    security = File.read(File.join(PROJECT_ROOT, ".github", "workflows", "security.yml"))

    assert_includes security, "bundle-audit check --update"
    assert_includes security, "cargo audit --deny warnings"
    assert_includes security, "permissions:\n  contents: read"
    refute_includes security, "secrets."
    refute_includes security, "GEM_HOST_API_KEY"
    refute_includes security, "contents: write"
    refute_includes security, "id-token: write"
  end

  def test_canonical_verification_prints_dependency_versions
    verify = File.read(File.join(PROJECT_ROOT, "script", "verify"))
    rakefile = File.read(File.join(PROJECT_ROOT, "Rakefile"))

    assert_includes verify, "bundle exec rake dependency:versions"
    assert_includes rakefile, '"cargo", "tree"'
    assert_includes rakefile, "Bundler.load.specs"
  end

  private

  def dependabot_update(config, ecosystem)
    config.fetch("updates").find { |entry| entry.fetch("package-ecosystem") == ecosystem }
  end

  def read_doc(path)
    File.read(File.join(PROJECT_ROOT, path))
  end
end
