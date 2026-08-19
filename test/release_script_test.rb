# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'test_helper'

class ReleaseScriptTest < Minitest::Test
  RELEASE_FILES = %w[
    script/release
    Cargo.lock
    lib/dry/validation/rust/version.rb
    ext/dry_validation_rust/Cargo.toml
    ext/dry_validation_rust/Cargo.lock
    CHANGELOG.md
  ].freeze

  def test_bumps_versions_changelog_commits_and_tags_a_clean_checkout
    Dir.mktmpdir('dry-validation-rust-release') do |directory|
      release_root = prepare_release_repository(directory)
      stdout, stderr, status = Open3.capture3(
        { 'RELEASE_DATE' => '2026-08-19' },
        File.join(release_root, 'script', 'release'), '0.2.0', chdir: release_root
      )

      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert_includes File.read(File.join(release_root, 'lib/dry/validation/rust/version.rb')), "VERSION = '0.2.0'"
      assert_includes File.read(File.join(release_root, 'ext/dry_validation_rust/Cargo.toml')), 'version = "0.2.0"'
      assert_includes File.read(File.join(release_root, 'Cargo.lock')), 'version = "0.2.0"'
      assert_includes File.read(File.join(release_root, 'ext/dry_validation_rust/Cargo.lock')), 'version = "0.2.0"'
      assert_includes File.read(File.join(release_root, 'CHANGELOG.md')), '## [0.2.0] - 2026-08-19'
      assert_equal 'Release 0.2.0', git(release_root, 'log', '-1', '--format=%s')
      assert_equal 'v0.2.0', git(release_root, 'tag', '--points-at', 'HEAD')
    end
  end

  def test_rejects_invalid_versions_without_modifying_the_checkout
    Dir.mktmpdir('dry-validation-rust-release') do |directory|
      release_root = prepare_release_repository(directory)
      _stdout, stderr, status = Open3.capture3(
        File.join(release_root, 'script', 'release'), '0.2', chdir: release_root
      )

      refute_predicate status, :success?
      assert_includes stderr, 'VERSION must be'
      assert_empty git(release_root, 'status', '--porcelain')
    end
  end

  def test_rejects_a_dirty_checkout_without_creating_a_release
    Dir.mktmpdir('dry-validation-rust-release') do |directory|
      release_root = prepare_release_repository(directory)
      File.write(File.join(release_root, 'CHANGELOG.md'), "uncommitted\n", mode: 'a')
      _stdout, stderr, status = Open3.capture3(
        File.join(release_root, 'script', 'release'), '0.2.0', chdir: release_root
      )

      refute_predicate status, :success?
      assert_includes stderr, 'dirty working tree'
      assert_empty git(release_root, 'tag')
    end
  end

  private

  def prepare_release_repository(directory)
    RELEASE_FILES.each do |path|
      destination = File.join(directory, path)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(PROJECT_ROOT, path), destination)
    end
    FileUtils.chmod('+x', File.join(directory, 'script', 'release'))

    git(directory, 'init', '--quiet')
    git(directory, 'config', 'user.name', 'Release test')
    git(directory, 'config', 'user.email', 'release-test@example.test')
    git(directory, 'add', '.')
    git(directory, 'commit', '--quiet', '-m', 'Initial state')
    directory
  end

  def git(directory, *)
    stdout, stderr, status = Open3.capture3('git', *, chdir: directory)
    assert_predicate status, :success?, stderr
    stdout.strip
  end
end
