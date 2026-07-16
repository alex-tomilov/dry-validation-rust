# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require_relative "../script/support/github_project_management"

class GitHubProjectManagementSyncTest < Minitest::Test
  Sync = DryValidationRust::GitHubProjectManagement

  def test_manifest_is_complete_and_references_declared_objects
    manifest = load_manifest

    assert_equal 27, manifest.labels.size
    assert_equal 5, manifest.milestones.size
    assert_equal 25, manifest.roadmap.size
    assert_equal manifest.roadmap.map { |item| item.fetch("id") }.uniq.size, manifest.roadmap.size

    manifest.roadmap.each do |item|
      assert File.file?(manifest.stage_path(item)), item.fetch("id")
      assert_empty item.fetch("labels") - manifest.label_names, item.fetch("id")
      assert_includes manifest.milestone_titles, item.fetch("milestone"), item.fetch("id")
    end
  end

  def test_manifest_rejects_unsupported_project_owner_type
    source = load_manifest
    manifest = Sync::Manifest.allocate
    manifest.instance_variable_set(:@root, source.root)
    manifest.instance_variable_set(:@data, source.data.merge("project" => source.project.merge("owner_type" => "organization")))
    manifest.instance_variable_set(:@labels, source.labels)

    error = assert_raises(Sync::Error) { manifest.send(:validate!) }

    assert_includes error.message, "unsupported project owner_type"
  end

  def test_empty_remote_plan_creates_every_managed_object_without_deletions
    actions = Sync::Planner.new(load_manifest, Sync::Snapshot.empty).actions
    counts = actions.group_by(&:kind).transform_values(&:size)

    assert_equal 85, actions.size
    assert_equal 27, counts.fetch(:create_label)
    assert_equal 5, counts.fetch(:create_milestone)
    assert_equal 1, counts.fetch(:create_project)
    assert_equal 1, counts.fetch(:sync_workflow)
    assert_equal 1, counts.fetch(:create_project_view)
    assert_equal 25, counts.fetch(:create_issue)
    assert_equal 25, counts.fetch(:add_project_item)
    refute actions.any? { |action| action.kind.to_s.start_with?("delete") }
  end

  def test_fully_synchronized_remote_has_no_actions
    manifest = load_manifest
    actions = Sync::Planner.new(manifest, synchronized_snapshot(manifest)).actions

    assert_empty actions
  end

  def test_planner_updates_managed_metadata_without_removing_unmanaged_values
    manifest = load_manifest
    snapshot = synchronized_snapshot(manifest)
    snapshot.labels["type:bug"]["description"] = "stale"
    snapshot.labels["unmanaged"] = {"color" => "ffffff", "description" => "preserve me"}
    snapshot.milestones["0.1 alpha - correctness foundation"]["state"] = "closed"
    snapshot.issues.fetch("T01")["labels"] << "unmanaged"

    actions = Sync::Planner.new(manifest, snapshot).actions

    assert actions.any? { |action| action.kind == :update_label && action.key == "type:bug" }
    assert actions.any? { |action| action.kind == :update_milestone && action.key.start_with?("0.1 alpha") }
    refute actions.any? { |action| action.key == "unmanaged" }
    refute actions.any? { |action| action.kind == :update_issue && action.key == "T01" }
    refute actions.any? { |action| action.kind.to_s.start_with?("delete") }
  end

  def test_planner_preserves_existing_project_item_workflow
    manifest = load_manifest
    snapshot = synchronized_snapshot(manifest)
    issue = snapshot.issues.fetch("T03")
    snapshot.project.fetch("items").fetch(issue.fetch("node_id"))["workflow"] = "Done"

    actions = Sync::Planner.new(manifest, snapshot).actions

    refute actions.any? { |action| action.key == "T03" && action.kind.to_s.include?("workflow") }
    assert_empty actions
  end

  def test_planner_ignores_unmanaged_workflow_options
    manifest = load_manifest
    snapshot = synchronized_snapshot(manifest)
    snapshot.project.fetch("workflow").fetch("options") << {
      "id" => "UNMANAGED",
      "name" => "Waiting",
      "color" => "PINK",
      "description" => "Owned outside the synchronizer"
    }

    actions = Sync::Planner.new(manifest, snapshot).actions

    refute actions.any? { |action| action.kind == :sync_workflow }
    assert_empty actions
  end

  def test_planner_does_not_restore_mutable_status_labels
    manifest = load_manifest
    snapshot = synchronized_snapshot(manifest)
    issue = snapshot.issues.fetch("G00")
    issue["labels"].delete("status:blocked")

    actions = Sync::Planner.new(manifest, snapshot).actions

    refute actions.any? { |action| action.kind == :update_issue && action.key == "G00" }
    assert_empty actions
  end

  def test_component_filter_limits_the_plan
    actions = Sync::Planner.new(
      load_manifest,
      Sync::Snapshot.empty,
      components: ["labels"]
    ).actions

    assert_equal 27, actions.size
    assert_equal [:create_label], actions.map(&:kind).uniq
  end

  def test_issue_only_plan_does_not_create_or_modify_project_items
    actions = Sync::Planner.new(
      load_manifest,
      Sync::Snapshot.empty,
      components: ["issues"]
    ).actions

    assert_equal 25, actions.size
    assert_equal [:create_issue], actions.map(&:kind).uniq
  end

  def test_generated_issue_body_contains_quality_sections_and_stable_marker
    manifest = load_manifest
    item = manifest.roadmap.find { |candidate| candidate.fetch("id") == "T03" }
    body = Sync::IssueBody.new(manifest, item).render

    assert_includes body, "<!-- dvr-roadmap:T03 -->"
    assert_includes body, "## Problem"
    assert_includes body, "## User or maintainer impact"
    assert_includes body, "## Current behavior and evidence"
    assert_includes body, "## Desired behavior"
    assert_includes body, "## Non-goals"
    assert_includes body, "## Expected affected files and ownership boundaries"
    assert_includes body, "## Implementation notes"
    assert_includes body, "## Test and verification plan"
    assert_includes body, "## Acceptance criteria"
    assert_includes body, "## Dependencies and blockers"
    assert_includes body, "## Risks and rollback"
    assert_includes body, "`T02`"
    assert_includes body, "script/verify"
  end

  def test_offline_cli_is_dry_run_and_does_not_use_client
    output = StringIO.new
    error = StringIO.new
    client = Object.new
    def client.method_missing(name, *_args)
      raise "unexpected client call: #{name}"
    end

    status = Sync::CLI.new(
      ["--offline"],
      root: PROJECT_ROOT,
      output: output,
      error: error,
      client: client
    ).run

    assert_equal 0, status
    assert_empty error.string
    assert_includes output.string, "Mode: dry-run (offline)"
    assert_match(/create_label\s+27/, output.string)
    assert_match(/create_issue\s+25/, output.string)
    assert_match(/add_project_item\s+25/, output.string)
    assert_includes output.string, "Offline dry-run assumes no managed remote objects exist."
  end

  def test_cli_rejects_offline_apply
    output = StringIO.new
    error = StringIO.new

    status = Sync::CLI.new(
      ["--offline", "--apply"],
      root: PROJECT_ROOT,
      output: output,
      error: error
    ).run

    assert_equal 1, status
    assert_includes error.string, "--offline cannot be combined with --apply"
  end

  def test_live_cli_reports_authentication_failure_without_applying
    output = StringIO.new
    error = StringIO.new
    client = Object.new
    def client.auth_status!
      raise DryValidationRust::GitHubProjectManagement::Error, "invalid test token"
    end

    status = Sync::CLI.new(
      [],
      root: PROJECT_ROOT,
      output: output,
      error: error,
      client: client
    ).run

    assert_equal 1, status
    assert_includes error.string, "invalid test token"
    refute_includes output.string, "Applied"
  end

  def test_help_exits_successfully
    output = StringIO.new
    error = StringIO.new

    status = Sync::CLI.new(
      ["--help"],
      root: PROJECT_ROOT,
      output: output,
      error: error
    ).run

    assert_equal 0, status
    assert_empty error.string
    assert_includes output.string, "Usage: script/sync-github-project-management"
  end

  def test_rest_client_uses_versioned_github_api_headers
    runner = RecordingRunner.new("[]")
    client = Sync::GhClient.new(runner: runner)

    assert_equal [], client.rest(:get, "/repos/example/project/labels")

    command = runner.commands.fetch(0)
    assert_includes command, "Accept: application/vnd.github+json"
    assert_includes command, "X-GitHub-Api-Version: 2026-03-10"
    assert_includes command, "/repos/example/project/labels"
  end

  def test_label_update_uses_new_name_and_preserves_no_delete_policy
    client = RecordingApiClient.new
    executor = Sync::Executor.new(client, load_manifest)
    action = Sync::Action.new(
      :update_label,
      "type:bug",
      {
        "name" => "type:bug",
        "color" => "d73a4a",
        "description" => "Updated description"
      }
    )

    executor.apply([action])

    call = client.rest_calls.fetch(0)
    assert_equal :patch, call.fetch(:method)
    assert_includes call.fetch(:path), "type%3Abug"
    assert_equal "type:bug", call.fetch(:body).fetch("new_name")
    refute call.fetch(:body).key?("name")
  end

  def test_user_project_view_path_uses_owner_login
    executor = Sync::Executor.new(RecordingApiClient.new, load_manifest)

    path = executor.send(:project_view_path, 5)

    assert_equal "/users/alex-tomilov/projectsV2/5/views", path
    refute_includes path, "85821448"
  end

  def test_created_issue_is_cached_from_post_response
    manifest = load_manifest
    client = IssueCreationClient.new(manifest)
    executor = Sync::Executor.new(client, manifest)
    action = Sync::Planner.new(manifest, Sync::Snapshot.empty).actions.find do |candidate|
      candidate.kind == :create_issue && candidate.key == "R01"
    end

    executor.send(:create_issue, action)
    issue = executor.send(:issues).fetch("R01")

    assert_equal 41, issue.fetch("number")
    assert_equal "ISSUE_R01", issue.fetch("node_id")
    refute client.rest_calls.any? { |call| call.fetch(:path).include?("/issues?") }
  end

  def test_workflow_merge_preserves_unmanaged_options
    executor = Sync::Executor.new(RecordingApiClient.new, load_manifest)
    field = {
      "options" => [
        {"id" => "BACKLOG", "name" => "Backlog", "color" => "GRAY", "description" => "Old"},
        {"id" => "WAITING", "name" => "Waiting", "color" => "PINK", "description" => "External"}
      ]
    }
    desired = load_manifest.project.fetch("workflow_options")

    merged = executor.send(:merged_workflow_options, field, desired)

    assert_equal "BACKLOG", merged.find { |option| option.fetch("name") == "Backlog" }.fetch("id")
    assert_equal(
      {"id" => "WAITING", "name" => "Waiting", "color" => "PINK", "description" => "External"},
      merged.find { |option| option.fetch("name") == "Waiting" }
    )
  end

  def test_workflow_merge_reuses_case_insensitive_option_and_can_prune_new_project_defaults
    executor = Sync::Executor.new(RecordingApiClient.new, load_manifest)
    field = {
      "options" => [
        {"id" => "IN_PROGRESS", "name" => "In Progress", "color" => "YELLOW", "description" => "Default"},
        {"id" => "TODO", "name" => "Todo", "color" => "GRAY", "description" => "Default"}
      ]
    }
    desired = load_manifest.project.fetch("workflow_options")

    merged = executor.send(
      :merged_workflow_options,
      field,
      desired,
      preserve_unmanaged: false
    )

    assert_equal "IN_PROGRESS", merged.find { |option| option.fetch("name") == "In progress" }.fetch("id")
    refute merged.any? { |option| option.fetch("name") == "Todo" }
  end

  def test_live_snapshot_rejects_unmarked_same_title_project
    manifest = load_manifest
    client = ProjectCollisionClient.new(manifest)

    error = assert_raises(Sync::Error) do
      Sync::LiveGitHub.new(client, manifest).snapshot
    end

    assert_includes error.message, "project title collision"
  end

  def test_project_snapshot_uses_bounded_graphql_queries
    discovery = Sync::LiveGitHub::PROJECT_QUERY

    assert_includes discovery, "projectsV2(first: 100)"
    refute_includes discovery, "fields(first:"
    refute_includes discovery, "items(first:"
    refute_includes discovery, "views(first:"
    assert_includes Sync::LiveGitHub::PROJECT_FIELDS_QUERY, "fields(first: 100)"
    assert_includes Sync::LiveGitHub::PROJECT_ITEMS_QUERY, "fieldValueByName(name: $workflowField)"
    assert_includes Sync::LiveGitHub::PROJECT_VIEWS_QUERY, "views(first: 100)"
  end

  def test_live_snapshot_reconstructs_project_from_split_queries
    manifest = load_manifest
    client = SplitProjectClient.new(manifest)

    project = Sync::LiveGitHub.new(client, manifest).snapshot.project

    assert_equal "PROJECT", project.fetch("id")
    assert_equal "STATUS", project.fetch("workflow").fetch("id")
    assert_equal "Done", project.fetch("items").fetch("ISSUE").fetch("workflow")
    assert_equal [{"name" => "Roadmap", "layout" => "TABLE_LAYOUT"}], project.fetch("views")
    assert_equal 4, client.graphql_calls.size
  end

  private

  class RecordingRunner
    Status = Data.define do
      def success?
        true
      end
    end

    attr_reader :commands

    def initialize(stdout)
      @stdout = stdout
      @commands = []
    end

    def run(*command, stdin_data: nil)
      @commands << command
      Sync::CommandRunner::Result.new(@stdout, "", Status.new)
    end
  end

  class RecordingApiClient
    attr_reader :rest_calls

    def initialize
      @rest_calls = []
    end

    def rest(method, path, body: nil, paginate: false)
      @rest_calls << {method: method, path: path, body: body, paginate: paginate}
      {}
    end
  end

  class IssueCreationClient
    attr_reader :rest_calls

    def initialize(manifest)
      @manifest = manifest
      @rest_calls = []
    end

    def rest(method, path, body: nil, paginate: false)
      @rest_calls << {method: method, path: path, body: body, paginate: paginate}
      return milestones if path.include?("/milestones?")
      return created_issue(body) if method == :post && path.end_with?("/issues")

      []
    end

    private

    def milestones
      @manifest.milestones.each_with_index.map do |milestone, index|
        milestone.merge("number" => index + 1, "state" => "open")
      end
    end

    def created_issue(body)
      {
        "number" => 41,
        "node_id" => "ISSUE_R01",
        "title" => body.fetch("title"),
        "labels" => body.fetch("labels").map { |name| {"name" => name} },
        "milestone" => {"title" => @manifest.milestones.fetch(body.fetch("milestone") - 1).fetch("title")}
      }
    end
  end

  class ProjectCollisionClient
    def initialize(manifest)
      @manifest = manifest
    end

    def rest(_method, _path, body: nil, paginate: false)
      []
    end

    def graphql(_query, _variables = {})
      {
        "user" => {
          "id" => "USER",
          "databaseId" => 1,
          "projectsV2" => {
            "nodes" => [
              {
                "id" => "PROJECT",
                "number" => 1,
                "title" => @manifest.project.fetch("title"),
                "shortDescription" => nil,
                "readme" => "Owned manually",
                "public" => true,
                "fields" => {"nodes" => []},
                "items" => {"nodes" => []},
                "views" => {"nodes" => []}
              }
            ]
          }
        },
        "repository" => {"id" => "REPOSITORY"}
      }
    end
  end

  class SplitProjectClient
    attr_reader :graphql_calls

    def initialize(manifest)
      @manifest = manifest
      @graphql_calls = []
    end

    def rest(_method, _path, body: nil, paginate: false)
      []
    end

    def graphql(query, variables = {})
      @graphql_calls << {query: query, variables: variables}

      case query
      when Sync::LiveGitHub::PROJECT_QUERY
        {
          "user" => {
            "id" => "USER",
            "databaseId" => 1,
            "projectsV2" => {
              "nodes" => [
                {
                  "id" => "PROJECT",
                  "number" => 1,
                  "title" => @manifest.project.fetch("title"),
                  "shortDescription" => "Roadmap",
                  "readme" => @manifest.project.fetch("readme"),
                  "public" => true
                }
              ]
            }
          }
        }
      when Sync::LiveGitHub::PROJECT_FIELDS_QUERY
        {
          "node" => {
            "fields" => {
              "nodes" => [
                {
                  "id" => "STATUS",
                  "name" => @manifest.project.fetch("workflow_field"),
                  "dataType" => "SINGLE_SELECT",
                  "databaseId" => 2,
                  "options" => [{"id" => "DONE", "name" => "Done", "color" => "GREEN", "description" => ""}]
                }
              ]
            }
          }
        }
      when Sync::LiveGitHub::PROJECT_ITEMS_QUERY
        {
          "node" => {
            "items" => {
              "nodes" => [
                {
                  "id" => "ITEM",
                  "content" => {"id" => "ISSUE", "number" => 1},
                  "workflowValue" => {"name" => "Done"}
                }
              ]
            }
          }
        }
      when Sync::LiveGitHub::PROJECT_VIEWS_QUERY
        {"node" => {"views" => {"nodes" => [{"name" => "Roadmap", "layout" => "TABLE_LAYOUT"}]}}}
      else
        raise "unexpected GraphQL query"
      end
    end
  end

  def load_manifest
    Sync::Manifest.new(root: PROJECT_ROOT, path: ".github/project-management.yml")
  end

  def synchronized_snapshot(manifest)
    labels = manifest.labels.to_h do |label|
      [label.fetch("name"), label.slice("color", "description")]
    end
    milestones = manifest.milestones.each_with_index.to_h do |milestone, index|
      [
        milestone.fetch("title"),
        milestone.merge("number" => index + 1, "state" => "open")
      ]
    end
    issues = manifest.roadmap.each_with_index.to_h do |item, index|
      [
        item.fetch("id"),
        {
          "number" => index + 1,
          "node_id" => "ISSUE_#{item.fetch("id")}",
          "title" => "[#{item.fetch("id")}] #{item.fetch("title")}",
          "labels" => item.fetch("labels").dup,
          "milestone" => item.fetch("milestone")
        }
      ]
    end
    project = {
      "id" => "PROJECT",
      "number" => 1,
      "title" => manifest.project.fetch("title"),
      "short_description" => manifest.project.fetch("short_description"),
      "readme" => manifest.project.fetch("readme"),
      "public" => manifest.project.fetch("public"),
      "workflow" => {
        "id" => "WORKFLOW",
        "database_id" => 100,
        "options" => manifest.project.fetch("workflow_options").map(&:dup)
      },
      "views" => [{"name" => manifest.project.fetch("view").fetch("name")}],
      "items" => issues.to_h do |_key, issue|
        [issue.fetch("node_id"), {"item_id" => "ITEM_#{issue.fetch("number")}", "workflow" => "Backlog"}]
      end
    }

    Sync::Snapshot.new(
      labels: labels,
      milestones: milestones,
      issues: issues,
      project: project
    )
  end
end
