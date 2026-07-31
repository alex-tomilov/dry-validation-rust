# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class SupplyChainTest < Minitest::Test
  def test_dependabot_covers_bundler_cargo_and_github_actions
    config = YAML.safe_load_file(File.join(PROJECT_ROOT, '.github', 'dependabot.yml'))
    updates = config.fetch('updates')

    ecosystems = updates.map { |entry| [entry.fetch('package-ecosystem'), entry.fetch('directory')] }
    assert_includes ecosystems, ['bundler', '/']
    assert_includes ecosystems, ['cargo', '/ext/dry_validation_rust']
    assert_includes ecosystems, ['github-actions', '/']

    updates.each do |entry|
      assert_equal 'weekly', entry.fetch('schedule').fetch('interval')
      assert_operator entry.fetch('open-pull-requests-limit'), :<=, 5
    end
  end

  def test_native_bridge_updates_are_isolated
    config = YAML.safe_load_file(File.join(PROJECT_ROOT, '.github', 'dependabot.yml'))

    bundler = dependabot_update(config, 'bundler')
    cargo = dependabot_update(config, 'cargo')

    assert_equal %w[rb_sys rake-compiler-dock], bundler.fetch('groups').fetch('ruby-native-bridge').fetch('patterns')
    assert_equal %w[magnus rb-sys], cargo.fetch('groups').fetch('rust-native-bridge').fetch('patterns')
  end

  def test_security_workflow_has_least_privilege_and_no_publish_credentials
    security = File.read(File.join(PROJECT_ROOT, '.github', 'workflows', 'security.yml'))

    assert_includes security, "permissions:\n  contents: read"
    refute_includes security, 'secrets.'
    refute_includes security, 'GEM_HOST_API_KEY'
    refute_includes security, 'contents: write'
    refute_includes security, 'id-token: write'
  end

  private

  def dependabot_update(config, ecosystem)
    config.fetch('updates').find { |entry| entry.fetch('package-ecosystem') == ecosystem }
  end
end
