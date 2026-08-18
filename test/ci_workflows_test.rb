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
    assert_equal(%w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin],
                 build.fetch('strategy').fetch('matrix').fetch('include').map { |h| h.fetch('platform') })

    steps = build.fetch('steps')
    build_source = steps.map { |step| step['run'] }.compact.join("\n")
    assert_includes build_source, 'rb-sys-dock'
    assert_includes build_source, '--platform ${{ matrix.platform }}'
    assert_includes build_source, '--mount-toolchains'
    assert_includes build_source, '--build'
    assert_includes steps.map { |step| step['uses'] }.compact, 'sigstore/cosign-installer@v4.1.2'
    assert_includes build_source, 'cosign sign-blob'
    assert_includes build_source, '--yes'
    assert_includes build_source, '--bundle'
    assert_includes steps.map { |step| step['uses'] }.compact, 'actions/upload-artifact@v7'
  end

  def test_native_gem_workflow_installs_the_locked_bundle_in_the_build_container
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'native-gems.yml'))
    build = workflow.fetch('jobs').fetch('build-native-gem')
    source = build.fetch('steps').map { |step| step['run'] }.compact.join("\n")

    assert_includes source, 'rb-sys-dock'
    assert_includes source, '--mount-toolchains'
    assert_includes source, '--build'
  end

  def test_release_workflow_verifies_tag_or_manual_release_tag_then_uses_trusted_publishing
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'rubygems-push.yml'))
    jobs = workflow.fetch('jobs')

    verify_steps = jobs.fetch('verify-release').fetch('steps')
    verify_source = verify_steps.map { |step| step['run'] }.compact.join("\n")
    assert_includes verify_source, '"${RELEASE_TAG}" != "${EXPECTED_TAG}"'
    verify_context = verify_steps.find { |step| step['name'] == 'Verify execution context' }
    assert_equal '${{ inputs.release_tag }}', verify_context.fetch('env').fetch('RELEASE_TAG')
    assert_equal '${{ inputs.mode }}', verify_context.fetch('env').fetch('MODE')
    assert_includes verify_steps.map { |step| step['run'] }.compact, 'script/verify'

    dispatch = workflow.fetch(true).fetch('workflow_dispatch')
    assert_equal({
                   'description' => 'Existing v* tag; required only for publish-existing-tag',
                   'required' => false,
                   'type' => 'string'
                 }, dispatch.fetch('inputs').fetch('release_tag'))
    assert_equal %w[preflight publish-existing-tag], dispatch.fetch('inputs').fetch('mode').fetch('options')

    publish = jobs.fetch('publish')
    assert_equal({ 'contents' => 'write', 'id-token' => 'write' }, publish.fetch('permissions'))
    assert_equal 'release', publish.fetch('environment')
    publish_source = publish.fetch('steps').map { |step| step['uses'].to_s + step['run'].to_s }.join("\n")
    assert_includes publish_source, 'rubygems/configure-rubygems-credentials@v2.1.0'
    assert_includes publish_source, 'gem push "${artifact}"'
    refute_includes File.read(File.join(WORKFLOW_DIR, 'rubygems-push.yml')), 'GEM_HOST_API_KEY'
  end

  def test_ci_profiles_ruby_allocations_against_the_main_baseline
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('memory-regression')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal 'ubuntu-latest', job.fetch('runs-on')
    assert_includes source, 'git show FETCH_HEAD:benchmark/baseline_allocations.json'
    assert_includes source, 'test/memory_regression_test.rb'
    assert_equal '1', job.fetch('steps').last.fetch('env').fetch('MEMORY_REGRESSION')
  end

  def test_ci_rejects_criterion_regressions_against_main_on_pull_requests
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('native-benchmarks')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal 'Criterion regression gate', job.fetch('name')
    refute job.key?('continue-on-error')
    assert_includes source, 'git show FETCH_HEAD:benchmark/baseline.json'
    assert_includes source, 'No Criterion baseline yet'
    assert_includes source, 'script/compare-criterion-baselines "$RUNNER_TEMP/criterion-baseline.json" "$RUNNER_TEMP/candidate-target/criterion"'
  end

  def test_manual_workflow_records_an_artifact_without_writing_to_the_repository
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'record-allocation-baseline.yml'))
    job = workflow.fetch('jobs').fetch('record')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal({ 'workflow_dispatch' => nil }, workflow.fetch(true))
    assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'))
    assert_includes source, 'script/record-allocation-baseline "$RUNNER_TEMP/baseline_allocations.json"'
    assert_includes job.fetch('steps').last.fetch('uses'), 'actions/upload-artifact@v7'
    assert_equal '${{ runner.temp }}/baseline_allocations.json', job.fetch('steps').last.fetch('with').fetch('path')
  end

  def test_manual_workflow_records_a_criterion_baseline_artifact
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'record-criterion-baseline.yml'))
    job = workflow.fetch('jobs').fetch('record')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal({ 'workflow_dispatch' => nil }, workflow.fetch(true))
    assert_includes source, 'script/record-criterion-baseline'
    assert_equal '${{ runner.temp }}/baseline.json', job.fetch('steps').last.fetch('with').fetch('path')
  end

  def test_actions_use_reviewable_version_pins
    workflows.each_key do |path|
      File.read(path).scan(/uses:\s+([^@\s]+)@([^\s]+)/).each do |action, ref|
        assert_match(/\A(?:v\d+(?:\.\d+){0,2}|[a-f0-9]{40})\z/, ref, "#{path}: #{action}@#{ref}")
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
