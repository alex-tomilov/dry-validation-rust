# frozen_string_literal: true

require_relative 'test_helper'

class CompatibilityGeneratorTest < Minitest::Test
  def test_generates_the_checked_in_compatibility_document_from_yaml
    stdout, stderr, status = ExecutableScriptTestHelper.capture(
      'script/generate-compatibility-md', chdir: PROJECT_ROOT
    )

    assert_predicate status, :success?, stderr
    assert_equal File.read(File.join(PROJECT_ROOT, 'docs/COMPATIBILITY.md')), stdout
  end
end
