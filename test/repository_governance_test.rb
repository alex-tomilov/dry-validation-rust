# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class RepositoryGovernanceTest < Minitest::Test
  PUSH_WORKFLOWS = %w[
    .github/workflows/ci.yml
    .github/workflows/compatibility.yml
    .github/workflows/package.yml
    .github/workflows/security.yml
  ].freeze

  REQUIRED_CHECKS = [
    "Ruby 3.3 on ubuntu-latest",
    "Ruby 3.3 on macos-latest",
    "Ruby 3.4 on ubuntu-latest",
    "Ruby 3.4 on macos-latest",
    "Ruby 3.5 on ubuntu-latest",
    "Ruby 3.5 on macos-latest",
    "Rust quality on 1.85.0",
    "Rust quality on stable",
    "Loading modes and installed gem",
    "Pinned upstream preflight",
    "Source gem audit",
    "Dependency audit",
    "CodeQL"
  ].freeze

  def test_main_is_the_only_integration_and_push_branch
    manifest = YAML.safe_load_file(project_path(".github/project-management.yml"))

    assert_equal "main", manifest.fetch("integration_branch")

    PUSH_WORKFLOWS.each do |path|
      workflow = read_file(path)

      assert_match(/^\s+- main\s*$/, workflow, path)
      refute_match(/^\s+- develop\s*$/, workflow, path)
    end
  end

  def test_governance_documents_the_branch_transition_and_protection_target
    governance = read_file("GOVERNANCE.md")

    assert_includes governance, "`main` is the sole long-lived integration and release branch"
    assert_includes governance, "retire `develop`"
    assert_match(/managed roadmap issue links from `develop` to `main`/, governance)
    assert_includes governance, "require pull requests"
    assert_includes governance, "block force pushes"
    assert_includes governance, "block branch deletion"
    assert_includes governance, "require conversation resolution"
    assert_includes governance, "squash merge"

    REQUIRED_CHECKS.each do |check|
      assert_includes governance, "`#{check}`"
    end
  end

  def test_required_check_names_match_stable_workflow_job_names
    ci = read_file(".github/workflows/ci.yml")
    compatibility = read_file(".github/workflows/compatibility.yml")
    package = read_file(".github/workflows/package.yml")
    security = read_file(".github/workflows/security.yml")

    assert_includes ci, 'name: Ruby ${{ matrix.ruby }} on ${{ matrix.os }}'
    assert_includes ci, 'name: Rust quality on ${{ matrix.rust }}'
    assert_includes ci, "name: Loading modes and installed gem"
    assert_includes compatibility, "name: Pinned upstream preflight"
    assert_includes package, "name: Source gem audit"
    assert_includes security, "name: Dependency audit"
    assert_includes security, "name: CodeQL"
  end

  def test_contribution_policy_targets_main_and_defines_merge_behavior
    contributing = read_file("CONTRIBUTING.md")

    assert_match(/pull requests against\s+`main`/, contributing)
    assert_match(/short-lived feature(?: or maintenance)?\s+branches/, contributing)
    assert_includes contributing, "squash merge"
    assert_includes contributing, "linear history"
    assert_includes contributing, "conversation resolution"
    assert_includes contributing, "Do not force-push"
  end

  private

  def project_path(path)
    File.join(PROJECT_ROOT, path)
  end

  def read_file(path)
    File.read(project_path(path))
  end
end
