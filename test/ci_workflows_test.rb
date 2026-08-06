# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class CiWorkflowsTest < Minitest::Test
  WORKFLOW_DIR = File.join(PROJECT_ROOT, '.github', 'workflows')

  def test_non_release_workflows_parse_and_default_to_read_only
    workflows.each do |path, workflow|
      next if path.end_with?('rubygems-push.yml')

      assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'), path)
      assert workflow.key?('concurrency'), path
    end

    codeql = workflows.fetch(File.join(WORKFLOW_DIR, 'security.yml'))
                      .fetch('jobs')
                      .fetch('codeql')
    assert_equal({ 'contents' => 'read', 'security-events' => 'write' }, codeql.fetch('permissions'))
  end

  def test_non_release_workflows_contain_no_publication_path
    refute File.exist?(File.join(WORKFLOW_DIR, 'release.yml'))

    source = workflows.reject { |path, _| path.end_with?('rubygems-push.yml') }
                      .keys.map { |path| File.read(path) }.join("\n")
    refute_includes source, 'GEM_HOST_API_KEY'
    refute_includes source, 'gem push'
    refute_includes source, 'contents: write'
    refute_includes source, 'id-token: write'
  end

  def test_release_workflow_builds_signs_and_publishes_each_p0_platform_on_tags
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'rubygems-push.yml'))
    build = workflow.fetch('jobs').fetch('build-native-gem')

    assert_equal 'rubygems:push', workflow.fetch('name')
    assert_equal %w[v*], workflow.fetch(true).fetch('push').fetch('tags')
    assert_equal %w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin],
                 build.fetch('strategy').fetch('matrix').fetch('platform')

    steps = build.fetch('steps')
    assert_includes steps.map { |step| step['run'] }.compact.join("\n"), 'rb-sys-dock --platform'
    assert_includes steps.map { |step| step['uses'] }.compact, 'sigstore/cosign-installer@v4'
    assert_includes steps.map { |step| step['run'] }.compact.join("\n"), 'cosign sign-blob --yes --bundle'
    assert_includes steps.map { |step| step['uses'] }.compact, 'actions/upload-artifact@v7'
  end

  def test_release_workflow_verifies_tag_then_uses_trusted_publishing
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'rubygems-push.yml'))
    jobs = workflow.fetch('jobs')

    verify_steps = jobs.fetch('verify-release').fetch('steps')
    assert_includes verify_steps.map { |step| step['run'] }.compact.join("\n"), 'test "${GITHUB_REF_NAME}" = "v${VERSION}"'
    assert_includes verify_steps.map { |step| step['run'] }.compact, 'script/verify'

    publish = jobs.fetch('publish')
    assert_equal({ 'contents' => 'read', 'id-token' => 'write' }, publish.fetch('permissions'))
    assert_equal 'release', publish.fetch('environment')
    publish_source = publish.fetch('steps').map { |step| step['uses'].to_s + step['run'].to_s }.join("\n")
    assert_includes publish_source, 'rubygems/configure-rubygems-credentials@v2'
    assert_includes publish_source, 'gem push "${artifact}"'
    refute_includes File.read(File.join(WORKFLOW_DIR, 'rubygems-push.yml')), 'GEM_HOST_API_KEY'
  end

  def test_actions_use_reviewable_version_pins
    workflows.each_key do |path|
      File.read(path).scan(/uses:\s+([^@\s]+)@([^\s]+)/).each do |action, ref|
        assert_match(/\Av\d+\z|[a-f0-9]{40}\z/, ref, "#{path}: #{action}@#{ref}")
      end
    end
  end

  private

  def workflows
    @workflows ||= Dir[File.join(WORKFLOW_DIR, '*.yml')].to_h do |path|
      [path, YAML.safe_load_file(path)]
    end
  end
end
