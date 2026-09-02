# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative 'test_helper'

class GemContentsScriptTest < Minitest::Test
  def test_generates_the_source_gem_manifest_at_the_requested_path
    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'gem_contents.txt')
      _stdout, stderr, status = ExecutableScriptTestHelper.capture(
        'script/update-gem-contents', output_path, chdir: PROJECT_ROOT
      )

      assert_predicate status, :success?, stderr
      assert_equal File.read(File.join(PROJECT_ROOT, 'expected_gem_contents.txt')), File.read(output_path)
    end
  end
end
