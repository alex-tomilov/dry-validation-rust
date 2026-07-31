# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class CiWorkflowsTest < Minitest::Test
  WORKFLOW_DIR = File.join(PROJECT_ROOT, '.github', 'workflows')

  def test_workflows_parse_and_default_to_read_only
    workflows.each do |path, workflow|
      assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'), path)
      assert workflow.key?('concurrency'), path
    end

    codeql = workflows.fetch(File.join(WORKFLOW_DIR, 'security.yml'))
                      .fetch('jobs')
                      .fetch('codeql')
    assert_equal({ 'contents' => 'read', 'security-events' => 'write' }, codeql.fetch('permissions'))
  end

  def test_pull_request_workflows_contain_no_publication_path
    refute File.exist?(File.join(WORKFLOW_DIR, 'release.yml'))

    source = workflows.keys.map { |path| File.read(path) }.join("\n")
    refute_includes source, 'GEM_HOST_API_KEY'
    refute_includes source, 'gem push'
    refute_includes source, 'contents: write'
    refute_includes source, 'id-token: write'
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
