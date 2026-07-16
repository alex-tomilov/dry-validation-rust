# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class CommunityHealthTest < Minitest::Test
  ROOT_FILES = %w[
    CONTRIBUTING.md
    CODE_OF_CONDUCT.md
    SECURITY.md
    SUPPORT.md
    GOVERNANCE.md
  ].freeze

  ISSUE_FORMS = {
    "bug.yml" => %w[
      gem_version ruby_version rust_version platform loading_mode build_type
      reproducer expected actual upstream_comparison backtrace
    ],
    "compatibility.yml" => %w[
      rust_gem_version upstream_versions ruby_platform loading_mode
      contract_input upstream_output rust_output expected_scope
    ],
    "performance.yml" => %w[
      gem_version runtime_versions hardware iterations benchmark command
      raw_results memory semantic_check interpretation
    ],
    "feature.yml" => %w[
      problem proposed_behavior compatibility alternatives scope
    ]
  }.freeze

  def test_community_profile_files_exist
    ROOT_FILES.each do |path|
      assert File.file?(project_path(path)), "missing #{path}"
    end

    assert File.file?(project_path(".github/pull_request_template.md"))
    assert File.file?(issue_template_path("config.yml"))
    ISSUE_FORMS.each_key do |form|
      assert File.file?(issue_template_path(form)), "missing #{form}"
    end
  end

  def test_security_policy_has_private_route_and_conservative_support
    security = read_file("SECURITY.md")

    assert_includes security, "/security/advisories/new"
    assert_match(/Do not open a public issue/i, security)
    assert_includes security, "Latest `0.1.x` prerelease"
    assert_match(/within seven calendar\s+days/, security)
    assert_includes security, "target rather than an SLA"
    assert_includes security, "coordinate"
  end

  def test_contribution_policy_matches_repository_verification_and_scope
    contributing = read_file("CONTRIBUTING.md")

    assert_includes contributing, "script/verify"
    assert_includes contributing, "test/fixtures/baseline"
    assert_includes contributing, "cargo fmt --check"
    assert_includes contributing, "cargo clippy"
    assert_includes contributing, "CHANGELOG.md"
    assert_includes contributing, "generated native libraries"
    assert_includes contributing, "does not require a Contributor License Agreement"
    assert_includes contributing, "pull requests against"
    assert_includes contributing, "`main`"
  end

  def test_support_and_governance_match_single_maintainer_alpha
    support = read_file("SUPPORT.md")
    governance = read_file("GOVERNANCE.md")

    %w[Bugs Compatibility Feature Usage Performance Security].each do |category|
      assert_includes support, category
    end
    assert_includes support, "no response-time or resolution SLA"

    assert_includes governance, "single-maintainer project"
    assert_match(/Alexey\s+Tomilov/, governance)
    assert_includes governance, "`main` is the sole long-lived integration and release branch"
    assert_includes governance, "retire `develop`"
    assert_includes governance, "independent from dry-rb"
  end

  def test_issue_forms_are_valid_yaml_and_collect_required_reproduction_data
    ISSUE_FORMS.each do |filename, expected_ids|
      form = YAML.safe_load_file(issue_template_path(filename))

      assert form.fetch("name").is_a?(String), filename
      assert form.fetch("description").is_a?(String), filename
      assert form.fetch("body").is_a?(Array), filename

      ids = form.fetch("body").filter_map { |item| item["id"] }
      assert_empty expected_ids - ids, "#{filename} is missing fields: #{(expected_ids - ids).join(", ")}"
    end
  end

  def test_issue_template_config_disables_blank_issues_and_links_private_reporting
    config = YAML.safe_load_file(issue_template_path("config.yml"))

    assert_equal false, config.fetch("blank_issues_enabled")
    links = config.fetch("contact_links")
    assert links.any? { |link| link.fetch("url").end_with?("/security/advisories/new") }
    assert links.any? { |link| link.fetch("url").end_with?("/SUPPORT.md") }
  end

  def test_pull_request_template_requires_verification_and_release_boundaries
    template = read_file(".github/pull_request_template.md")

    assert_includes template, "script/verify"
    assert_match(/pinned upstream\s+versions/, template)
    assert_includes template, "benchmark evidence"
    assert_includes template, "generated native binaries"
    assert_includes template, "Did not publish a gem"
  end

  private

  def project_path(path)
    File.join(PROJECT_ROOT, path)
  end

  def issue_template_path(filename)
    project_path(File.join(".github", "ISSUE_TEMPLATE", filename))
  end

  def read_file(path)
    File.read(project_path(path))
  end
end
