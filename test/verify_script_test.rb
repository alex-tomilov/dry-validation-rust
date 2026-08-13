# frozen_string_literal: true

require_relative 'test_helper'

class VerifyScriptTest < Minitest::Test
  def test_bootstraps_cargo_audit_then_uses_its_cargo_subcommand
    source = File.read(File.join(PROJECT_ROOT, 'script', 'verify'))

    assert_includes source, 'cargo install cargo-audit --version 0.22.1 --locked'
    assert_includes source, '(cd ext/dry_validation_rust && run cargo audit)'
    refute_includes source, 'cargo-audit audit'
  end
end
