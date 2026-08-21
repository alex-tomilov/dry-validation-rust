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

    source = workflows.reject { |path, _| path.end_with?('rubygems-push.yml') || path.end_with?('benchmark-regression.yml') }
                      .keys.map { |path| File.read(path) }.join("\n")
    refute_includes source, 'GEM_HOST_API_KEY'
    refute_includes source, 'gem push'
    refute_includes source, 'contents: write'
    refute_includes source, 'id-token: write'
  end

  def test_ci_requires_changelog_updates_unless_the_pull_request_is_labeled
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    changelog = workflow.fetch('jobs').fetch('changelog')
    source = changelog.fetch('steps').last.fetch('run')

    assert_equal "github.event_name == 'pull_request'", changelog.fetch('if')
    assert_equal 0, changelog.fetch('steps').first.fetch('with').fetch('fetch-depth')
    assert_includes source, 'no-changelog'
    assert_includes source, 'git diff --quiet "${BASE_SHA}" "${HEAD_SHA}" -- CHANGELOG.md'
  end

  def test_security_workflow_scans_full_history_for_secrets
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'security.yml'))
    job = workflow.fetch('jobs').fetch('secret-scan')
    checkout = job.fetch('steps').first
    scan = job.fetch('steps').last

    assert_equal 'ubuntu-latest', job.fetch('runs-on')
    assert_equal 'actions/checkout@v7', checkout.fetch('uses')
    assert_equal 0, checkout.fetch('with').fetch('fetch-depth')
    assert_equal 'gitleaks/gitleaks-action@v3', scan.fetch('uses')
    assert_equal '${{ secrets.GITHUB_TOKEN }}', scan.fetch('env').fetch('GITHUB_TOKEN')
  end

  def test_release_workflow_builds_signs_and_publishes_each_p0_platform_on_tags
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'rubygems-push.yml'))
    build = workflow.fetch('jobs').fetch('build-native-gem')

    assert_equal 'rubygems:push', workflow.fetch('name')
    assert_equal %w[v*], workflow.fetch(true).fetch('push').fetch('tags')
    assert_equal(%w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin x64-mingw-ucrt],
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

    assert_equal(%w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin x64-mingw-ucrt],
                 build.fetch('strategy').fetch('matrix').fetch('include').map { |h| h.fetch('platform') })
    assert_includes source, 'rb-sys-dock'
    assert_includes source, '--mount-toolchains'
    assert_includes source, '--build'

    smoke = workflow.fetch('jobs').fetch('smoke-native-gem')
    assert_equal 'build-native-gem', smoke.fetch('needs')
    assert_equal(%w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin x64-mingw-ucrt],
                 smoke.fetch('strategy').fetch('matrix').fetch('include').map { |h| h.fetch('platform') })
    smoke_source = smoke.fetch('steps').map { |step| step['run'] }.compact.join("\n")
    assert_includes smoke_source, 'gem install --local'
    assert_includes smoke_source, 'require "dry/validation/rust"'
    assert_includes smoke_source, 'result.success?'
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

  def test_ci_validates_source_fallback_on_supported_hosted_runners
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('source-fallback')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal %w[ubuntu-latest macos-latest windows-latest], job.fetch('strategy').fetch('matrix').fetch('os')
    assert_equal "${{ runner.os == 'Windows' && '1.75.0-x86_64-pc-windows-gnu' || '1.75.0' }}",
                 job.fetch('steps').find { |step| step['name'] == 'Setup Rust toolchain' }.fetch('with').fetch('toolchain')
    assert_includes source, "gem install rb_sys --version '~> 0.9' --no-document"
    assert_includes source, 'ridk exec pacman -Sy --noconfirm --needed mingw-w64-ucrt-x86_64-clang'
    assert_includes source, 'LIBCLANG_PATH=$env:RI_DEVKIT\\ucrt64\\bin'
    assert_includes source, 'RUSTUP_TOOLCHAIN=1.75.0-x86_64-pc-windows-gnu'
    refute_includes source, 'choco install llvm'
    assert_includes source, 'gem build dry-validation-rust.gemspec'
    assert_includes source, 'gem install --local dry-validation-rust-*.gem --platform ruby'
    assert_includes source, 'require "dry/validation/rust"'
  end

  def test_ci_generates_and_uploads_ruby_coverage
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('ruby-coverage')
    steps = job.fetch('steps')
    upload = steps.find { |step| step['name'] == 'Upload Ruby coverage to Codecov' }

    assert_equal 'ubuntu-latest', job.fetch('runs-on')
    assert_includes steps.map { |step| step['run'].to_s }, 'bundle exec rake test'
    assert_equal 'codecov/codecov-action@v4', upload.fetch('uses')
    assert_equal './coverage/lcov.info', upload.fetch('with').fetch('files')
    assert_equal 'ruby', upload.fetch('with').fetch('flags')
    assert_equal File.join(PROJECT_ROOT, 'coverage', 'lcov.info'),
                 SimpleCov::Formatter::LcovFormatter.config.single_report_path

    codecov = YAML.safe_load_file(File.join(PROJECT_ROOT, 'codecov.yml'))
    ruby_status = codecov.fetch('coverage').fetch('status').fetch('project').fetch('ruby')
    assert_equal '70%', ruby_status.fetch('target')
    assert_equal '2%', ruby_status.fetch('threshold')
    assert_equal ['ruby'], ruby_status.fetch('flags')
  end

  def test_ruby_integration_cache_is_scoped_to_runner_architecture
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    setup_rust = workflow.fetch('jobs').fetch('ruby-integration').fetch('steps')
                         .find { |step| step['name'] == 'Setup Rust toolchain' }

    assert_equal 'ruby-native-${{ runner.arch }}-v2', setup_rust.fetch('with').fetch('cache-key')
  end

  def test_ruby_integration_tests_ruby_head_without_blocking_merges_and_reports_failures
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('ruby-integration')
    matrix = job.fetch('strategy').fetch('matrix')
    notification = job.fetch('steps').find { |step| step['name'] == 'Create or update Ruby head failure issue' }

    assert_equal %w[3.3 3.4 3.5 head], matrix.fetch('ruby')
    assert_equal "${{ matrix.ruby == 'head' }}", job.fetch('continue-on-error')
    assert_equal({ 'contents' => 'read', 'issues' => 'write' }, job.fetch('permissions'))
    ruby_setup = job.fetch('steps').find { |step| step['name'] == 'Setup Ruby and Bundler cache' }
    assert_equal "${{ matrix.ruby == 'head' && 'latest' || 'default' }}", ruby_setup.fetch('with').fetch('bundler')
    assert_equal "${{ matrix.ruby == 'head' && '4' || '' }}", ruby_setup.fetch('env').fetch('BUNDLER_VERSION')
    assert_equal "${{ failure() && matrix.ruby == 'head' }}", notification.fetch('if')
    assert_equal true, notification.fetch('continue-on-error')
    assert_equal 'actions/github-script@v7', notification.fetch('uses')
    assert_includes notification.fetch('with').fetch('script'), 'github.rest.issues.create'
  end

  def test_ruby_head_uses_the_upstream_magnus_typed_data_fix_on_stable_rust
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('ruby-integration')
    steps = job.fetch('steps')
    setup_rust = steps.find { |step| step['name'] == 'Setup Rust toolchain' }
    magnus = steps.find { |step| step['name'] == 'Use Magnus with Ruby head typed-data support' }

    assert_equal "${{ matrix.ruby == 'head' && 'stable' || '1.75.0' }}", setup_rust.fetch('with').fetch('toolchain')
    assert_equal "matrix.ruby == 'head'", magnus.fetch('if')
    assert_includes magnus.fetch('run'), '6d6024c8096c4f8c5288a81a30b7313feed099e6'
    assert_includes magnus.fetch('run'), 'cargo update --manifest-path ext/dry_validation_rust/Cargo.toml -p magnus'
  end

  def test_ci_exercises_runtime_dependency_boundaries
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('dependency-compatibility')
    matrix = job.fetch('strategy').fetch('matrix').fetch('include')

    assert_equal [
      { 'dependency' => 'bigdecimal', 'version' => '3.1.0' },
      { 'dependency' => 'bigdecimal', 'version' => '3.2.0' },
      { 'dependency' => 'bigdecimal', 'version' => '4.0.0' },
      { 'dependency' => 'rb_sys', 'version' => '0.9.100' },
      { 'dependency' => 'rb_sys', 'version' => '0.9.128' },
      { 'dependency' => 'rb_sys', 'version' => 'latest' }
    ], matrix

    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")
    assert_includes source, 'BUNDLE_GEMFILE=Gemfile.dependency-ci bundle exec rake test'
  end

  def test_ci_rejects_criterion_regressions_against_main_on_pull_requests
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'ci.yml'))
    job = workflow.fetch('jobs').fetch('native-benchmarks')
    source = job.fetch('steps').map { |step| step['run'].to_s }.join("\n")

    assert_equal 'Criterion regression gate (${{ matrix.bench }})', job.fetch('name')
    refute job.key?('continue-on-error')
    assert_includes source, 'git show FETCH_HEAD:benchmark/baseline.json'
    assert_includes source, 'No Criterion baseline yet'
    assert_includes source, 'script/compare-criterion-baselines "$RUNNER_TEMP/criterion-baseline.json" "$RUNNER_TEMP/candidate-target/criterion"'
  end

  def test_benchmark_workflow_gates_prs_and_only_publishes_from_trusted_events
    workflow = workflows.fetch(File.join(WORKFLOW_DIR, 'benchmark-regression.yml'))
    benchmark = workflow.fetch('jobs').fetch('benchmark')
    benchmark_action = benchmark.fetch('steps').find { |step| step['uses'] == 'benchmark-action/github-action-benchmark@v1' }
    publisher = workflow.fetch('jobs').fetch('publish-dashboard')
    publish_action = publisher.fetch('steps').find { |step| step['uses'] == 'benchmark-action/github-action-benchmark@v1' }

    assert workflow.fetch(true).key?('pull_request')
    assert workflow.fetch(true).key?('workflow_dispatch')
    assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'))
    assert_equal({ 'contents' => 'read' }, benchmark.fetch('permissions'))
    assert_equal({ 'contents' => 'write', 'deployments' => 'write' }, publisher.fetch('permissions'))
    assert_equal "github.ref == 'refs/heads/main' && (github.event_name != 'workflow_dispatch' || inputs.publish_dashboard)",
                 publisher.fetch('if').gsub(/\s+/, ' ')
    assert_includes benchmark.fetch('steps').map { |step| step['run'].to_s },
                    'gem install dry-validation --version 1.11.1 --no-document'
    assert_equal 'FORMAT=github-action-benchmark ruby -Ilib benchmark/schema_throughput.rb > benchmark_results.json',
                 benchmark.fetch('steps').find { |step| step['name'] == 'Run schema throughput benchmark' }.fetch('run')
    assert_equal 'customSmallerIsBetter', benchmark_action.fetch('with').fetch('tool')
    assert_equal '105%', benchmark_action.fetch('with').fetch('fail-threshold')
    assert_equal true, benchmark_action.fetch('with').fetch('fail-on-alert')
    assert_equal false, benchmark_action.fetch('with').fetch('auto-push')
    assert_equal true, publish_action.fetch('with').fetch('auto-push')
  end

  def test_workflow_permission_values_are_static
    workflows.each do |path, workflow|
      permission_sets = [workflow['permissions']] + workflow.fetch('jobs').values.map { |job| job['permissions'] }
      permission_sets.compact.each do |permissions|
        permissions.each_value do |value|
          refute_match(/\$\{\{/, value.to_s, path)
        end
      end
    end
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
