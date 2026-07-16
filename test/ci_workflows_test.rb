# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class CiWorkflowsTest < Minitest::Test
  WORKFLOW_DIR = File.join(PROJECT_ROOT, ".github", "workflows")
  EXPECTED_WORKFLOWS = %w[
    ci.yml
    compatibility.yml
    security.yml
    package.yml
    fuzz.yml
  ].freeze

  def test_required_workflows_exist_without_release_workflow
    EXPECTED_WORKFLOWS.each do |workflow|
      assert File.file?(File.join(WORKFLOW_DIR, workflow)), "missing workflow #{workflow}"
    end

    refute File.exist?(File.join(WORKFLOW_DIR, "release.yml"))
  end

  def test_workflows_have_least_privilege_permissions_and_concurrency
    workflows.each do |path, workflow|
      assert_equal({"contents" => "read"}, workflow.fetch("permissions"), path)
      assert workflow.key?("concurrency"), path
      assert_includes File.read(path), "cancel-in-progress: true", path
    end

    security = YAML.safe_load_file(File.join(WORKFLOW_DIR, "security.yml"))
    assert_equal(
      {"contents" => "read", "security-events" => "write"},
      security.fetch("jobs").fetch("codeql").fetch("permissions")
    )
  end

  def test_actions_are_pinned_to_major_versions
    workflows.each_key do |path|
      File.read(path).scan(/uses:\s+([^@\s]+)@([^\s]+)/).each do |action, ref|
        assert_match(/\Av\d+\z|[a-f0-9]{40}\z/, ref, "#{path}: #{action}@#{ref} is not major-version or SHA pinned")
      end
    end
  end

  def test_ci_matrix_covers_supported_ruby_versions_and_rust_msrv
    ci = File.read(File.join(WORKFLOW_DIR, "ci.yml"))

    %w[3.3 3.4 3.5].each do |ruby_version|
      assert_includes ci, %("#{ruby_version}")
    end
    assert_includes ci, "ubuntu-latest"
    assert_includes ci, "macos-latest"
    assert_includes ci, "1.85.0"
    assert_includes ci, "stable"
    assert_includes ci, "cargo test --locked"
    assert_includes ci, "bundle exec rake package:audit"
    assert_includes ci, "Setup Ruby for rb-sys"
  end

  def test_loading_modes_are_checked_in_ci
    ci = File.read(File.join(WORKFLOW_DIR, "ci.yml"))

    assert_includes ci, 'require "dry/validation/rust"'
    assert_includes ci, 'require "dry/validation"'
    assert_includes ci, "expected exact-mode conflict"
    assert_includes ci, "bundle exec rake package:audit"
  end

  def test_compatibility_security_package_and_fuzz_workflows_have_required_checks
    compatibility = File.read(File.join(WORKFLOW_DIR, "compatibility.yml"))
    assert_includes compatibility, "gem install dry-validation -v 1.11.1"
    assert_includes compatibility, "gem install dry-schema -v 1.16.0"
    assert_includes compatibility, "compatibility-preflight.json"
    assert_includes compatibility, "actions/upload-artifact@v4"

    security = File.read(File.join(WORKFLOW_DIR, "security.yml"))
    assert_includes security, "bundle-audit check --update"
    refute_includes security, "bundle audit check"
    assert_includes security, "cargo install cargo-audit --version 0.22.1 --locked"
    refute_includes security, "cargo install cargo-audit --locked\n"
    assert_includes security, "cargo audit --deny warnings"
    assert_includes security, "github/codeql-action/analyze@v3"

    package = File.read(File.join(WORKFLOW_DIR, "package.yml"))
    assert_includes package, "bundle exec rake package:audit"
    assert_includes package, "pkg/*.gem"

    fuzz = File.read(File.join(WORKFLOW_DIR, "fuzz.yml"))
    assert_includes fuzz, "workflow_dispatch"
    assert_includes fuzz, "schedule:"
    assert_includes fuzz, "timeout 5m"
    assert_includes fuzz, "continue-on-error: true"
    refute_includes fuzz, "pull_request:"
  end

  private

  def workflows
    EXPECTED_WORKFLOWS.to_h do |workflow|
      path = File.join(WORKFLOW_DIR, workflow)
      [path, YAML.safe_load_file(path)]
    end
  end
end
