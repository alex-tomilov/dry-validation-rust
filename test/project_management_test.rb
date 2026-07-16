# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class ProjectManagementTest < Minitest::Test
  EXPECTED_LABELS = %w[
    type:bug
    type:compatibility
    type:performance
    type:feature
    type:documentation
    type:security
    type:maintenance
    priority:p0
    priority:p1
    priority:p2
    priority:p3
    area:ruby-dsl
    area:rust-engine
    area:ffi
    area:rules
    area:messages
    area:compatibility
    area:benchmark
    area:packaging
    area:ci
    area:docs
    status:needs-reproduction
    status:blocked
    status:needs-design
    status:good-first-issue
    breaking-change
    upstream-difference
  ].freeze

  MILESTONES = [
    "0.1 alpha - correctness foundation",
    "0.1 beta - compatibility and benchmark evidence",
    "0.1 RC - native packaging and release readiness",
    "1.0 - stable API and support policy",
    "Future - experimental batch API"
  ].freeze

  IMPLEMENTATION_FIELDS = %w[
    roadmap_reference
    priority
    milestone
    primary_area
    problem
    user_impact
    current_behavior
    desired_behavior
    non_goals
    affected_files
    implementation_notes
    tests
    acceptance_criteria
    dependencies
    risk_rollback
  ].freeze

  def test_label_catalog_is_complete_unique_and_documented
    labels = label_catalog
    names = labels.map { |label| label.fetch("name") }

    assert_equal EXPECTED_LABELS.sort, names.sort
    assert_equal names.uniq, names

    labels.each do |label|
      assert_match(/\A[0-9a-f]{6}\z/, label.fetch("color"), label.fetch("name"))
      refute_empty label.fetch("description"), label.fetch("name")
    end
  end

  def test_issue_forms_only_reference_declared_labels
    declared = label_catalog.map { |label| label.fetch("name") }

    issue_forms.each do |path, form|
      undeclared = form.fetch("labels", []) - declared
      assert_empty undeclared, "#{path} references undeclared labels: #{undeclared.join(", ")}"
    end
  end

  def test_implementation_form_collects_issue_quality_and_milestone_data
    form = YAML.safe_load_file(project_path(".github/ISSUE_TEMPLATE/implementation.yml"))
    fields = form.fetch("body").filter_map { |item| item["id"] }

    assert_empty IMPLEMENTATION_FIELDS - fields
    assert_equal ["status:needs-design"], form.fetch("labels")

    milestone = form.fetch("body").find { |item| item["id"] == "milestone" }
    assert_equal MILESTONES, milestone.fetch("attributes").fetch("options")
  end

  def test_remote_manifest_and_sync_script_exist
    manifest = YAML.safe_load_file(project_path(".github/project-management.yml"))
    script = read_file("script/sync-github-project-management")
    policy = read_file("docs/PROJECT_MANAGEMENT.md")

    assert_equal "alex-tomilov/dry-validation-rust", manifest.fetch("repository")
    assert_equal 5, manifest.fetch("milestones").size
    assert_equal 25, manifest.fetch("roadmap").size
    assert File.executable?(project_path("script/sync-github-project-management"))
    assert_includes script, "GitHubProjectManagement::CLI"
    assert_includes policy, "script/sync-github-project-management --apply"
    assert_includes policy, "never deletes unknown labels"
  end

  def test_project_policy_maps_every_stage_and_orders_p0_dependencies
    policy = read_file("docs/PROJECT_MANAGEMENT.md")
    stage_ids = [
      *(0..13).map { |number| format("T%02d", number) },
      *(0..12).map { |number| format("R%02d", number) },
      *(0..3).map { |number| format("G%02d", number) }
    ]

    stage_ids.each do |stage_id|
      assert_match(/`#{stage_id}`/, policy, "missing roadmap mapping for #{stage_id}")
    end

    ordered_p0 = %w[T01 T02 T03 T04 T06 G00].map { |stage_id| policy.index("[`#{stage_id}`") }
    refute_includes ordered_p0, nil
    assert_equal ordered_p0.sort, ordered_p0
  end

  def test_project_policy_defines_milestones_board_and_wip_limit
    policy = read_file("docs/PROJECT_MANAGEMENT.md")
    board = policy.split("## Project board", 2).fetch(1).split("## Triage and decomposition", 2).fetch(0)

    MILESTONES.each { |milestone| assert_includes policy, milestone }

    columns = %w[Backlog Ready In\ progress Review Blocked Done]
    positions = columns.map { |column| board.index("`#{column}`") }
    refute_includes positions, nil
    assert_equal positions.sort, positions

    assert_includes policy, "one active Codex implementation task by default"
    assert_includes policy, "status:good-first-issue"
    assert_includes policy, "make production ready"
  end

  def test_dependabot_uses_canonical_maintenance_labels
    dependabot = YAML.safe_load_file(project_path(".github/dependabot.yml"))
    declared = label_catalog.map { |label| label.fetch("name") }

    dependabot.fetch("updates").each do |update|
      labels = update.fetch("labels")
      assert_includes labels, "type:maintenance"
      assert_empty labels - declared
    end
  end

  private

  def label_catalog
    @label_catalog ||= YAML.safe_load_file(project_path(".github/labels.yml"))
  end

  def issue_forms
    Dir[project_path(".github/ISSUE_TEMPLATE/*.yml")].to_h do |path|
      [path, YAML.safe_load_file(path)]
    end
  end

  def project_path(path)
    File.join(PROJECT_ROOT, path)
  end

  def read_file(path)
    File.read(project_path(path))
  end
end
