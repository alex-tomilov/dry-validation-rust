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

  def test_generates_the_checked_in_support_matrix_and_ci_matrix_from_yaml
    stdout, stderr, status = ExecutableScriptTestHelper.capture(
      'script/generate-ci-matrix', '--support-doc', chdir: PROJECT_ROOT
    )

    assert_predicate status, :success?, stderr
    assert_equal File.read(File.join(PROJECT_ROOT, 'docs/SUPPORT_MATRIX.md')), stdout

    stdout, stderr, status = ExecutableScriptTestHelper.capture(
      'script/generate-ci-matrix', '--ci', chdir: PROJECT_ROOT
    )

    assert_predicate status, :success?, stderr
    assert_equal File.read(File.join(PROJECT_ROOT, '.github/workflows/ci.yml')), stdout
    assert_includes stdout, "        include:\n          - platform: x86_64-linux\n            os: ubuntu-latest\n            ruby: \"3.3\""
  end
end
