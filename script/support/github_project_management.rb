# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "pathname"
require "uri"
require "yaml"

module DryValidationRust
  module GitHubProjectManagement
    class Error < StandardError; end

    Action = Data.define(:kind, :key, :details) do
      def to_s
        "#{kind} #{key}"
      end
    end

    class Manifest
      PROJECT_MARKER = "<!-- dvr-project-management:v1 -->"

      attr_reader :root, :data, :labels

      def initialize(root:, path:)
        @root = Pathname(root)
        @path = @root.join(path)
        @data = YAML.safe_load_file(@path)
        labels_path = @root.join(@data.fetch("labels_file"))
        @labels = YAML.safe_load_file(labels_path)
        validate!
      end

      def repository
        data.fetch("repository")
      end

      def repository_owner
        repository.split("/", 2).fetch(0)
      end

      def repository_name
        repository.split("/", 2).fetch(1)
      end

      def integration_branch
        data.fetch("integration_branch")
      end

      def project
        data.fetch("project")
      end

      def milestones
        data.fetch("milestones")
      end

      def roadmap
        data.fetch("roadmap")
      end

      def label_names
        labels.map { |label| label.fetch("name") }
      end

      def milestone_titles
        milestones.map { |milestone| milestone.fetch("title") }
      end

      def stage_path(item)
        root.join(item.fetch("spec"))
      end

      private

      def validate!
        raise Error, "unsupported project-management manifest version" unless data.fetch("version") == 1
        raise Error, "repository must use OWNER/REPO format" unless repository.match?(%r{\A[^/]+/[^/]+\z})

        duplicate_labels = duplicates(label_names)
        raise Error, "duplicate labels: #{duplicate_labels.join(", ")}" unless duplicate_labels.empty?

        duplicate_milestones = duplicates(milestone_titles)
        raise Error, "duplicate milestones: #{duplicate_milestones.join(", ")}" unless duplicate_milestones.empty?

        owner_type = project.fetch("owner_type")
        raise Error, "unsupported project owner_type: #{owner_type.inspect}" unless owner_type == "user"

        ids = roadmap.map { |item| item.fetch("id") }
        duplicate_ids = duplicates(ids)
        raise Error, "duplicate roadmap ids: #{duplicate_ids.join(", ")}" unless duplicate_ids.empty?
        raise Error, "project readme must contain #{PROJECT_MARKER}" unless project.fetch("readme").include?(PROJECT_MARKER)

        roadmap.each do |item|
          unknown_labels = item.fetch("labels") - label_names
          raise Error, "#{item.fetch("id")} uses unknown labels: #{unknown_labels.join(", ")}" unless unknown_labels.empty?
          raise Error, "#{item.fetch("id")} uses an unknown milestone" unless milestone_titles.include?(item.fetch("milestone"))
          raise Error, "#{item.fetch("id")} stage file does not exist" unless stage_path(item).file?
        end

        known_ids = ids + %w[R00 R02 R03 R04 R05 T00 R09]
        roadmap.each do |item|
          unknown_dependencies = item.fetch("dependencies") - known_ids
          next if unknown_dependencies.empty?

          raise Error, "#{item.fetch("id")} has unknown dependencies: #{unknown_dependencies.join(", ")}"
        end
      end

      def duplicates(values)
        values.tally.select { |_value, count| count > 1 }.keys
      end
    end

    class StageDocument
      def initialize(path)
        @path = path
        @text = File.read(path)
      end

      def assignment
        clean_section(section("Assignment"))
      end

      def acceptance_criteria
        value = section("Acceptance criteria")
        value = gate_checklist if value.empty?
        clean_section(value)
      end

      def non_goals
        value = section("Scope control")
        value = section("Implementation rule") if value.empty?
        clean_section(value)
      end

      def affected_files
        value = section("Files")
        return "Determine the focused file set from the current repository before editing." if value.empty?

        clean_section(value)
      end

      private

      def section(name)
        match = @text.match(/^## #{Regexp.escape(name)}\s*$\n(.*?)(?=^## |\z)/m)
        match ? match[1] : ""
      end

      def gate_checklist
        match = @text.match(/^# \d+\..*?\n(.*?)(?=^---\s*$|\z)/m)
        match ? match[1] : ""
      end

      def clean_section(value)
        cleaned = value
          .gsub(/^>.*$\n?/, "")
          .gsub(/^\*\*(?:Priority|Suggested branch|Dependencies):\*\*.*$\n?/, "")
          .gsub(/^---\s*$\n?/, "")
          .strip
        cleaned.empty? ? "Follow the linked stage specification." : cleaned
      end
    end

    class IssueBody
      def initialize(manifest, item)
        @manifest = manifest
        @item = item
        @stage = StageDocument.new(manifest.stage_path(item))
      end

      def render
        dependency_text = @item.fetch("dependencies")
          .map { |dependency| "`#{dependency}`" }
          .join(", ")
        dependency_text = "None" if dependency_text.empty?

        <<~MARKDOWN
          <!-- dvr-roadmap:#{@item.fetch("id")} -->

          ## Problem

          #{@stage.assignment}

          ## User or maintainer impact

          This work is part of the `#{@item.fetch("milestone")}` milestone. It is tracked separately so correctness, compatibility, and release evidence can be reviewed without a broad production-readiness umbrella issue.

          ## Current behavior and evidence

          Audit the current repository before editing. Partial implementation does not count as completion without the tests and evidence required by the linked stage.

          ## Desired behavior

          Complete the focused `#{@item.fetch("id")}` task described by [`#{@item.fetch("stage")}`](https://github.com/#{@manifest.repository}/blob/#{@manifest.integration_branch}/#{@item.fetch("spec")}).

          ## Non-goals

          #{@stage.non_goals}

          ## Expected affected files and ownership boundaries

          #{@stage.affected_files}

          ## Implementation notes

          Preserve the Ruby/Rust ownership boundaries and correctness invariants in `AGENTS.md`. Implement only this issue and keep unsupported behavior explicit.

          ## Test and verification plan

          Add focused regression and boundary tests, then run `script/verify`. Compatibility claims require separate-process differential evidence; performance claims require reproducible benchmark evidence.

          ## Acceptance criteria

          #{@stage.acceptance_criteria}

          ## Dependencies and blockers

          #{dependency_text}

          ## Risks and rollback

          Document semantic, FFI, compatibility, packaging, or support risks discovered during implementation. The rollback is the focused pull request revert; publication, tags, releases, and repository-setting changes are out of scope.
        MARKDOWN
      end
    end

    class Snapshot
      attr_reader :labels, :milestones, :issues, :project

      def self.empty
        new(labels: {}, milestones: {}, issues: {}, project: nil)
      end

      def initialize(labels:, milestones:, issues:, project:)
        @labels = labels
        @milestones = milestones
        @issues = issues
        @project = project
      end
    end

    class Planner
      MANAGED_COMPONENTS = %w[labels milestones project issues].freeze

      def initialize(manifest, snapshot, components: MANAGED_COMPONENTS)
        @manifest = manifest
        @snapshot = snapshot
        @components = components
      end

      def actions
        @actions ||= [
          *label_actions,
          *milestone_actions,
          *project_actions,
          *issue_actions
        ]
      end

      private

      def enabled?(component)
        @components.include?(component)
      end

      def label_actions
        return [] unless enabled?("labels")

        @manifest.labels.filter_map do |desired|
          current = @snapshot.labels[desired.fetch("name")]
          if current.nil?
            Action.new(:create_label, desired.fetch("name"), desired)
          elsif current.slice("color", "description") != desired.slice("color", "description")
            Action.new(:update_label, desired.fetch("name"), desired)
          end
        end
      end

      def milestone_actions
        return [] unless enabled?("milestones")

        @manifest.milestones.filter_map do |desired|
          current = @snapshot.milestones[desired.fetch("title")]
          if current.nil?
            Action.new(:create_milestone, desired.fetch("title"), desired)
          elsif current.fetch("description", "") != desired.fetch("description") || current.fetch("state") != "open"
            Action.new(:update_milestone, desired.fetch("title"), desired)
          end
        end
      end

      def project_actions
        return [] unless enabled?("project")

        desired = @manifest.project
        current = @snapshot.project
        return missing_project_actions(desired) if current.nil?

        actions = []
        metadata = desired.slice("title", "short_description", "readme", "public")
        current_metadata = current.slice("title", "short_description", "readme", "public")
        actions << Action.new(:update_project, desired.fetch("title"), metadata) if metadata != current_metadata

        desired_options = desired.fetch("workflow_options")
        current_options = current.dig("workflow", "options") || []
        actions << Action.new(:sync_workflow, desired.fetch("workflow_field"), {"options" => desired_options}) unless workflow_equal?(current_options, desired_options)

        view_name = desired.fetch("view").fetch("name")
        view_names = current.fetch("views", []).map { |view| view.fetch("name") }
        actions << Action.new(:create_project_view, view_name, desired.fetch("view")) unless view_names.include?(view_name)
        actions
      end

      def missing_project_actions(desired)
        [
          Action.new(:create_project, desired.fetch("title"), desired),
          Action.new(:sync_workflow, desired.fetch("workflow_field"), {"options" => desired.fetch("workflow_options")}),
          Action.new(:create_project_view, desired.fetch("view").fetch("name"), desired.fetch("view"))
        ]
      end

      def workflow_equal?(current, desired)
        desired.all? do |desired_option|
          current_option = current.find { |candidate| candidate.fetch("name") == desired_option.fetch("name") }
          current_option && current_option.slice("name", "color", "description") == desired_option.slice("name", "color", "description")
        end
      end

      def issue_actions
        return [] unless enabled?("issues")

        @manifest.roadmap.flat_map do |item|
          current = @snapshot.issues[item.fetch("id")]
          actions = []
          if current.nil?
            actions << Action.new(:create_issue, item.fetch("id"), desired_issue(item))
          else
            stable_labels = item.fetch("labels").reject { |label| label.start_with?("status:") }
            missing_labels = stable_labels - current.fetch("labels")
            wrong_milestone = current.fetch("milestone") != item.fetch("milestone")
            wrong_title = current.fetch("title") != issue_title(item)
            if missing_labels.any? || wrong_milestone || wrong_title
              actions << Action.new(
                :update_issue,
                item.fetch("id"),
                desired_issue(item).merge("labels" => stable_labels, "missing_labels" => missing_labels)
              )
            end
          end

          project_item = @snapshot.project&.dig("items", current&.fetch("node_id", nil))
          if enabled?("project") && project_item.nil?
            actions << Action.new(:add_project_item, item.fetch("id"), {"workflow" => "Backlog"})
          end
          actions
        end
      end

      def desired_issue(item)
        {
          "title" => issue_title(item),
          "body" => IssueBody.new(@manifest, item).render,
          "labels" => item.fetch("labels"),
          "milestone" => item.fetch("milestone")
        }
      end

      def issue_title(item)
        "[#{item.fetch("id")}] #{item.fetch("title")}"
      end
    end

    class CommandRunner
      Result = Data.define(:stdout, :stderr, :status)

      def run(*command, stdin_data: nil)
        stdout, stderr, status = Open3.capture3(*command, stdin_data: stdin_data)
        Result.new(stdout, stderr, status)
      end
    end

    class GhClient
      def initialize(runner: CommandRunner.new)
        @runner = runner
      end

      def auth_status!
        result = @runner.run("gh", "auth", "status", "-h", "github.com")
        return if result.status.success?

        raise Error, "GitHub CLI authentication failed:\n#{result.stderr.strip}"
      end

      def rest(method, path, body: nil, paginate: false)
        command = [
          "gh", "api",
          "-H", "Accept: application/vnd.github+json",
          "-H", "X-GitHub-Api-Version: 2026-03-10",
          "--method", method.to_s.upcase
        ]
        command.concat(["--paginate", "--slurp"]) if paginate
        command.concat(["--input", "-"]) if body
        command << path
        result = @runner.run(*command, stdin_data: body && JSON.generate(body))
        raise_api_error(command, result) unless result.status.success?

        parsed = result.stdout.empty? ? nil : JSON.parse(result.stdout)
        paginate ? parsed.flatten : parsed
      end

      def graphql(query, variables = {})
        payload = {"query" => query, "variables" => variables}
        result = @runner.run("gh", "api", "graphql", "--input", "-", stdin_data: JSON.generate(payload))
        raise_api_error(["gh", "api", "graphql"], result) unless result.status.success?

        parsed = JSON.parse(result.stdout)
        errors = parsed["errors"]
        raise Error, "GitHub GraphQL error: #{errors.map { |error| error["message"] }.join("; ")}" if errors&.any?

        parsed.fetch("data")
      end

      private

      def raise_api_error(command, result)
        message = result.stderr.strip
        message = result.stdout.strip if message.empty?
        raise Error, "#{command.join(" ")} failed: #{message}"
      end
    end

    class LiveGitHub
      PROJECT_QUERY = <<~GRAPHQL
        query($login: String!) {
          user(login: $login) {
            id
            databaseId
            projectsV2(first: 100) {
              nodes {
                id
                number
                title
                shortDescription
                readme
                public
              }
            }
          }
        }
      GRAPHQL

      PROJECT_FIELDS_QUERY = <<~GRAPHQL
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              fields(first: 100) {
                nodes {
                  ... on ProjectV2FieldCommon {
                    id
                    name
                    dataType
                  }
                  ... on ProjectV2SingleSelectField {
                    databaseId
                    options {
                      id
                      name
                      color
                      description
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      PROJECT_ITEMS_QUERY = <<~GRAPHQL
        query($projectId: ID!, $workflowField: String!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              items(first: 100) {
                nodes {
                  id
                  content {
                    ... on Issue {
                      id
                      number
                    }
                  }
                  workflowValue: fieldValueByName(name: $workflowField) {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      PROJECT_VIEWS_QUERY = <<~GRAPHQL
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              views(first: 100) {
                nodes {
                  name
                  layout
                }
              }
            }
          }
        }
      GRAPHQL

      def initialize(client, manifest)
        @client = client
        @manifest = manifest
      end

      def snapshot
        Snapshot.new(
          labels: labels,
          milestones: milestones,
          issues: issues,
          project: project
        )
      end

      private

      def labels
        @client.rest(:get, "/repos/#{@manifest.repository}/labels?per_page=100", paginate: true).to_h do |label|
          [label.fetch("name"), label.slice("color", "description")]
        end
      end

      def milestones
        @client.rest(:get, "/repos/#{@manifest.repository}/milestones?state=all&per_page=100", paginate: true).to_h do |milestone|
          [
            milestone.fetch("title"),
            milestone.slice("number", "title", "description", "state")
          ]
        end
      end

      def issues
        remote = @client.rest(:get, "/repos/#{@manifest.repository}/issues?state=all&per_page=100", paginate: true)
        remote.reject { |issue| issue.key?("pull_request") }.filter_map do |issue|
          match = issue.fetch("body", "").match(/<!-- dvr-roadmap:([A-Z0-9]+) -->/)
          next unless match

          [
            match[1],
            {
              "number" => issue.fetch("number"),
              "node_id" => issue.fetch("node_id"),
              "title" => issue.fetch("title"),
              "labels" => issue.fetch("labels").map { |label| label.fetch("name") },
              "milestone" => issue["milestone"]&.fetch("title")
            }
          ]
        end.to_h
      end

      def project
        desired = @manifest.project
        data = @client.graphql(
          PROJECT_QUERY,
          {"login" => desired.fetch("owner")}
        )
        owner = data.fetch("user")
        project = owner.fetch("projectsV2").fetch("nodes").find { |candidate| candidate.fetch("title") == desired.fetch("title") }
        return nil unless project
        unless project["readme"].to_s.include?(Manifest::PROJECT_MARKER)
          raise Error, "project title collision: #{desired.fetch("title").inspect} is not managed by this synchronizer"
        end

        project_id = project.fetch("id")
        fields = @client.graphql(PROJECT_FIELDS_QUERY, {"projectId" => project_id}).fetch("node").fetch("fields").fetch("nodes")
        remote_items = @client.graphql(
          PROJECT_ITEMS_QUERY,
          {"projectId" => project_id, "workflowField" => desired.fetch("workflow_field")}
        ).fetch("node").fetch("items").fetch("nodes")
        views = @client.graphql(PROJECT_VIEWS_QUERY, {"projectId" => project_id}).fetch("node").fetch("views").fetch("nodes")

        workflow = fields.find { |field| field["name"] == desired.fetch("workflow_field") }
        items = remote_items.filter_map do |item|
          issue = item["content"]
          next unless issue

          [issue.fetch("id"), {"item_id" => item.fetch("id"), "workflow" => item["workflowValue"]&.fetch("name")}]
        end.to_h

        {
          "id" => project_id,
          "number" => project.fetch("number"),
          "title" => project.fetch("title"),
          "short_description" => project["shortDescription"],
          "readme" => project["readme"],
          "public" => project.fetch("public"),
          "workflow" => workflow && {
            "id" => workflow.fetch("id"),
            "database_id" => workflow["databaseId"],
            "options" => workflow.fetch("options", [])
          },
          "views" => views,
          "items" => items
        }
      end
    end

    class Executor
      CREATE_PROJECT = <<~GRAPHQL
        mutation($ownerId: ID!, $repositoryId: ID!, $title: String!) {
          createProjectV2(input: {ownerId: $ownerId, repositoryId: $repositoryId, title: $title}) {
            projectV2 { id number title }
          }
        }
      GRAPHQL

      UPDATE_PROJECT = <<~GRAPHQL
        mutation($projectId: ID!, $title: String!, $shortDescription: String!, $readme: String!, $public: Boolean!) {
          updateProjectV2(input: {
            projectId: $projectId,
            title: $title,
            shortDescription: $shortDescription,
            readme: $readme,
            public: $public
          }) {
            projectV2 { id }
          }
        }
      GRAPHQL

      CREATE_FIELD = <<~GRAPHQL
        mutation($projectId: ID!, $name: String!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
          createProjectV2Field(input: {
            projectId: $projectId,
            dataType: SINGLE_SELECT,
            name: $name,
            singleSelectOptions: $options
          }) {
            projectV2Field { ... on ProjectV2SingleSelectField { id } }
          }
        }
      GRAPHQL

      UPDATE_FIELD = <<~GRAPHQL
        mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
          updateProjectV2Field(input: {fieldId: $fieldId, singleSelectOptions: $options}) {
            projectV2Field { ... on ProjectV2SingleSelectField { id } }
          }
        }
      GRAPHQL

      ADD_PROJECT_ITEM = <<~GRAPHQL
        mutation($projectId: ID!, $contentId: ID!) {
          addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
            item { id }
          }
        }
      GRAPHQL

      SET_PROJECT_FIELD = <<~GRAPHQL
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId,
            itemId: $itemId,
            fieldId: $fieldId,
            value: {singleSelectOptionId: $optionId}
          }) {
            projectV2Item { id }
          }
        }
      GRAPHQL

      OWNER_QUERY = <<~GRAPHQL
        query($login: String!, $repoOwner: String!, $repoName: String!) {
          user(login: $login) { id databaseId }
          repository(owner: $repoOwner, name: $repoName) { id }
        }
      GRAPHQL

      PROJECT_FIELDS_QUERY = <<~GRAPHQL
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              fields(first: 100) {
                nodes {
                  ... on ProjectV2FieldCommon { id name dataType }
                  ... on ProjectV2SingleSelectField {
                    databaseId
                    options { id name color description }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      def initialize(client, manifest)
        @client = client
        @manifest = manifest
      end

      def apply(actions)
        actions.each do |action|
          case action.kind
          when :create_label then create_label(action)
          when :update_label then update_label(action)
          when :create_milestone then create_milestone(action)
          when :update_milestone then update_milestone(action)
          when :create_project then ensure_project
          when :update_project then update_project
          when :sync_workflow then sync_workflow
          when :create_project_view then create_project_view
          when :create_issue then create_issue(action)
          when :update_issue then update_issue(action)
          when :add_project_item then ensure_project_item(action)
          else raise Error, "unsupported action #{action.kind}"
          end
        end
      end

      private

      def create_label(action)
        @client.rest(:post, "/repos/#{@manifest.repository}/labels", body: action.details)
      end

      def update_label(action)
        name = URI.encode_www_form_component(action.key)
        @client.rest(
          :patch,
          "/repos/#{@manifest.repository}/labels/#{name}",
          body: action.details.slice("color", "description").merge("new_name" => action.key)
        )
      end

      def create_milestone(action)
        @client.rest(:post, "/repos/#{@manifest.repository}/milestones", body: action.details.merge("state" => "open"))
      end

      def update_milestone(action)
        milestone = milestones.fetch(action.key)
        @client.rest(
          :patch,
          "/repos/#{@manifest.repository}/milestones/#{milestone.fetch("number")}",
          body: action.details.merge("state" => "open")
        )
      end

      def ensure_project
        return project if project

        owner = owner_data
        desired = @manifest.project
        response = @client.graphql(
          CREATE_PROJECT,
          {
            "ownerId" => owner.fetch("user").fetch("id"),
            "repositoryId" => owner.fetch("repository").fetch("id"),
            "title" => desired.fetch("title")
          }
        )
        created = response.fetch("createProjectV2").fetch("projectV2")
        @project_created = true
        @project = {
          "id" => created.fetch("id"),
          "number" => created.fetch("number"),
          "title" => created.fetch("title"),
          "short_description" => nil,
          "readme" => nil,
          "public" => false,
          "workflow" => nil,
          "views" => [],
          "items" => {}
        }
        update_project
        project
      end

      def update_project
        desired = @manifest.project
        current = project || ensure_project
        @client.graphql(
          UPDATE_PROJECT,
          {
            "projectId" => current.fetch("id"),
            "title" => desired.fetch("title"),
            "shortDescription" => desired.fetch("short_description"),
            "readme" => desired.fetch("readme"),
            "public" => desired.fetch("public")
          }
        )
        clear_project_cache
        project
      end

      def sync_workflow
        current_project = project || ensure_project
        desired = @manifest.project
        field = project_fields(current_project.fetch("id")).find { |candidate| candidate["name"] == desired.fetch("workflow_field") }
        options = merged_workflow_options(
          field,
          desired.fetch("workflow_options"),
          preserve_unmanaged: !@project_created
        )
        if field
          @client.graphql(UPDATE_FIELD, {"fieldId" => field.fetch("id"), "options" => options})
        else
          @client.graphql(
            CREATE_FIELD,
            {
              "projectId" => current_project.fetch("id"),
              "name" => desired.fetch("workflow_field"),
              "options" => options
            }
          )
        end
        clear_project_cache
      end

      def create_project_view
        current_project = project || ensure_project
        field = project_fields(current_project.fetch("id")).find { |candidate| candidate["name"] == @manifest.project.fetch("workflow_field") }
        raise Error, "workflow field is missing after synchronization" unless field

        desired = @manifest.project.fetch("view")
        @client.rest(
          :post,
          project_view_path(current_project.fetch("number")),
          body: {
            "name" => desired.fetch("name"),
            "layout" => desired.fetch("layout"),
            "filter" => desired.fetch("filter"),
            "visible_fields" => [field.fetch("databaseId")]
          }
        )
        clear_project_cache
      end

      def project_view_path(project_number)
        owner = URI.encode_www_form_component(@manifest.project.fetch("owner"))
        "/users/#{owner}/projectsV2/#{project_number}/views"
      end

      def merged_workflow_options(field, desired_options, preserve_unmanaged: true)
        existing_options = field&.fetch("options", []) || []
        desired_names = desired_options.map { |option| option.fetch("name").downcase }
        managed = desired_options.map do |option|
          existing = existing_options.find do |candidate|
            candidate.fetch("name").casecmp?(option.fetch("name"))
          end
          option.merge(existing ? {"id" => existing.fetch("id")} : {})
        end
        unmanaged = if preserve_unmanaged
          existing_options
            .reject { |option| desired_names.include?(option.fetch("name").downcase) }
            .map { |option| option.slice("id", "name", "color", "description") }
        else
          []
        end
        managed + unmanaged
      end

      def create_issue(action)
        details = action.details
        milestone = milestones.fetch(details.fetch("milestone"))
        created = @client.rest(
          :post,
          "/repos/#{@manifest.repository}/issues",
          body: {
            "title" => details.fetch("title"),
            "body" => details.fetch("body"),
            "labels" => details.fetch("labels"),
            "milestone" => milestone.fetch("number")
          }
        )
        @issues ||= {}
        @issues[action.key] = {
          "number" => created.fetch("number"),
          "node_id" => created.fetch("node_id"),
          "title" => created.fetch("title"),
          "labels" => created.fetch("labels").map { |label| label.fetch("name") },
          "milestone" => created.fetch("milestone").fetch("title")
        }
      end

      def update_issue(action)
        issue = issues.fetch(action.key)
        details = action.details
        milestone = milestones.fetch(details.fetch("milestone"))
        labels = (issue.fetch("labels") + details.fetch("labels")).uniq
        @client.rest(
          :patch,
          "/repos/#{@manifest.repository}/issues/#{issue.fetch("number")}",
          body: {
            "title" => details.fetch("title"),
            "labels" => labels,
            "milestone" => milestone.fetch("number")
          }
        )
        clear_issue_cache
      end

      def ensure_project_item(action)
        current_project = project || ensure_project
        issue = issues.fetch(action.key)
        item = current_project.fetch("items", {})[issue.fetch("node_id")]
        unless item
          response = @client.graphql(
            ADD_PROJECT_ITEM,
            {"projectId" => current_project.fetch("id"), "contentId" => issue.fetch("node_id")}
          )
          item = {"item_id" => response.fetch("addProjectV2ItemById").fetch("item").fetch("id")}
        end

        fields = project_fields(current_project.fetch("id"))
        workflow = fields.find { |field| field["name"] == @manifest.project.fetch("workflow_field") }
        option = workflow.fetch("options").find { |candidate| candidate.fetch("name") == action.details.fetch("workflow") }
        @client.graphql(
          SET_PROJECT_FIELD,
          {
            "projectId" => current_project.fetch("id"),
            "itemId" => item.fetch("item_id"),
            "fieldId" => workflow.fetch("id"),
            "optionId" => option.fetch("id")
          }
        )
        clear_project_cache
      end

      def labels
        @labels ||= LiveGitHub.new(@client, @manifest).send(:labels)
      end

      def milestones
        @milestones ||= LiveGitHub.new(@client, @manifest).send(:milestones)
      end

      def issues
        @issues ||= LiveGitHub.new(@client, @manifest).send(:issues)
      end

      def project
        @project ||= LiveGitHub.new(@client, @manifest).send(:project)
      end

      def owner_data
        @owner_data ||= @client.graphql(
          OWNER_QUERY,
          {
            "login" => @manifest.project.fetch("owner"),
            "repoOwner" => @manifest.repository_owner,
            "repoName" => @manifest.repository_name
          }
        )
      end

      def project_fields(project_id)
        @client.graphql(PROJECT_FIELDS_QUERY, {"projectId" => project_id})
          .fetch("node")
          .fetch("fields")
          .fetch("nodes")
      end

      def clear_issue_cache
        @issues = nil
      end

      def clear_project_cache
        @project = nil
      end
    end

    class CLI
      DEFAULT_MANIFEST = ".github/project-management.yml"

      def initialize(argv, root:, output: $stdout, error: $stderr, client: nil)
        @argv = argv
        @root = root
        @output = output
        @error = error
        @client = client || GhClient.new
        @options = {
          apply: false,
          offline: false,
          verbose: false,
          manifest: DEFAULT_MANIFEST,
          components: Planner::MANAGED_COMPONENTS
        }
      end

      def run
        return 0 if parse! == :help
        raise Error, "--offline cannot be combined with --apply" if @options[:offline] && @options[:apply]

        manifest = Manifest.new(root: @root, path: @options[:manifest])
        snapshot = if @options[:offline]
          Snapshot.empty
        else
          @client.auth_status!
          LiveGitHub.new(@client, manifest).snapshot
        end
        actions = Planner.new(manifest, snapshot, components: @options[:components]).actions
        print_plan(actions)

        if @options[:apply]
          Executor.new(@client, manifest).apply(actions)
          @output.puts "Applied #{actions.size} action(s)."
        else
          @output.puts "Dry-run only. Re-run with --apply after reviewing the plan." unless @options[:offline]
          @output.puts "Offline dry-run assumes no managed remote objects exist." if @options[:offline]
        end
        0
      rescue OptionParser::ParseError, Error, KeyError, JSON::ParserError => e
        @error.puts "error: #{e.message}"
        1
      end

      private

      def parse!
        parser = OptionParser.new do |options|
          options.banner = "Usage: script/sync-github-project-management [options]"
          options.on("--apply", "Apply the planned remote changes") { @options[:apply] = true }
          options.on("--offline", "Plan against an empty remote without authentication") { @options[:offline] = true }
          options.on("--only LIST", "Comma-separated: labels,milestones,project,issues") do |value|
            components = value.split(",").map(&:strip)
            unknown = components - Planner::MANAGED_COMPONENTS
            raise OptionParser::InvalidArgument, "unknown components: #{unknown.join(", ")}" unless unknown.empty?

            @options[:components] = components
          end
          options.on("--manifest PATH", "Manifest path relative to the repository root") { |value| @options[:manifest] = value }
          options.on("--verbose", "Print every planned action") { @options[:verbose] = true }
          options.on("-h", "--help", "Show this help") do
            @output.puts options
            @help_requested = true
          end
        end

        parser.parse!(@argv)
        @help_requested ? :help : :ok
      end

      def print_plan(actions)
        counts = actions.group_by(&:kind).transform_values(&:size)
        @output.puts "Repository: #{Manifest.new(root: @root, path: @options[:manifest]).repository}"
        @output.puts "Mode: #{@options[:apply] ? "apply" : "dry-run"}#{@options[:offline] ? " (offline)" : ""}"
        if actions.empty?
          @output.puts "No changes required."
          return
        end

        counts.sort_by { |kind, _count| kind.to_s }.each do |kind, count|
          @output.puts format("  %-24s %d", kind, count)
        end
        return unless @options[:verbose]

        @output.puts
        actions.each { |action| @output.puts "- #{action}" }
      end
    end
  end
end
