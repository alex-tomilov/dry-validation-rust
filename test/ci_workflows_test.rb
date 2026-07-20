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
    container.yml
    clean-room.yml
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

  def test_container_workflow_separates_pr_build_from_publication
    path = File.join(WORKFLOW_DIR, "container.yml")
    container = YAML.safe_load_file(path)
    source = File.read(path)
    jobs = container.fetch("jobs")

    assert_includes source, "pull_request:"
    assert_includes source, "workflow_dispatch:"
    assert_includes source, '"build-week-*"'
    assert_includes source, '"v*.*.*"'
    refute_includes source, "branches:"
    refute_match(/type=raw,value=latest|type=raw,value=main/, source)
    assert_includes source, "latest=false"

    assert_equal({"contents" => "read"}, jobs.fetch("pull-request").fetch("permissions"))
    assert_equal(
      {"contents" => "read", "packages" => "write"},
      jobs.fetch("publish").fetch("permissions")
    )
    assert_equal(
      {"contents" => "read", "packages" => "read"},
      jobs.fetch("verify-published").fetch("permissions")
    )

    assert_includes source, "persist-credentials: false"
    assert_includes source, "docker/login-action@v3"
    assert_includes source, "password: ${{ secrets.GITHUB_TOKEN }}"
    assert_includes source, "platforms: linux/amd64"
    refute_includes source, "linux/arm64"
  end

  def test_container_workflow_pulls_and_tests_the_published_digest
    source = File.read(File.join(WORKFLOW_DIR, "container.yml"))

    assert_includes source, "type=sha,format=long,prefix=sha-"
    assert_includes source, "steps.build.outputs.digest"
    assert_includes source, "needs.publish.outputs.digest"
    assert_includes source, 'docker pull "${IMAGE_REFERENCE}"'
    assert_includes source, 'script/docker-smoke --skip-build --tag "${IMAGE_REFERENCE}"'
    assert_includes source, "GITHUB_STEP_SUMMARY"
    assert_includes source, "Published tags"
    assert_includes source, "Digest:"
  end

  def test_clean_room_workflow_adds_scheduled_no_cache_coverage
    path = File.join(WORKFLOW_DIR, "clean-room.yml")
    source = File.read(path)
    workflow = YAML.safe_load_file(path)

    assert_includes source, "workflow_dispatch:"
    assert_includes source, "schedule:"
    refute_includes source, "pull_request:"
    assert_equal({"contents" => "read"}, workflow.fetch("permissions"))
    assert_includes source, "script/clean-room-verify --docker-only"
    assert_includes source, 'local_docker_build" && $2 == "PASSED"'
    assert_includes source, 'local_docker_runtime" && $2 == "PASSED"'
    assert_includes source, "actions/upload-artifact@v4"
    assert_includes source, "persist-credentials: false"
    refute_includes source, "packages: write"
  end

  private

  def workflows
    EXPECTED_WORKFLOWS.to_h do |workflow|
      path = File.join(WORKFLOW_DIR, workflow)
      [path, YAML.safe_load_file(path)]
    end
  end
end
