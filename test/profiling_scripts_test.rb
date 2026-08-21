# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative 'test_helper'

class ProfilingScriptsTest < Minitest::Test
  def test_ruby_profile_script_generates_all_profile_artifacts
    with_profile_project do |project_root, bin_directory|
      write_executable(bin_directory, 'ruby', <<~BASH)
        #!/usr/bin/env bash
        if [[ "$*" == *' -e exit'* ]]; then
          exit 0
        fi
        touch "${@: -2:1}"
      BASH
      write_executable(bin_directory, 'stackprof', <<~BASH)
        #!/usr/bin/env bash
        if [[ "$*" == *--d3-flamegraph* ]]; then
          printf '<html>flamegraph</html>\n'
        else
          printf 'stackprof text report\n'
        fi
      BASH

      stdout, stderr, status = run_profile(project_root, bin_directory, 'profile-ruby')

      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert File.exist?(File.join(project_root, 'tmp', 'stackprof-cpu.dump'))
      assert File.exist?(File.join(project_root, 'tmp', 'profile.txt'))
      assert File.exist?(File.join(project_root, 'tmp', 'flamegraph.html'))
    end
  end

  def test_rust_profile_script_generates_a_flamegraph
    with_profile_project do |project_root, bin_directory|
      write_executable(bin_directory, 'perf', "#!/usr/bin/env bash\nexit 0\n")
      write_executable(bin_directory, 'cargo', <<~BASH)
        #!/usr/bin/env bash
        if [[ "$1" == flamegraph && "$2" != --version ]]; then
          touch flamegraph.svg
        fi
      BASH

      stdout, stderr, status = run_profile(project_root, bin_directory, 'profile-rust')

      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert File.exist?(File.join(project_root, 'ext', 'dry_validation_rust', 'flamegraph.svg'))
    end
  end

  def test_rust_profile_script_rejects_unavailable_perf_before_starting_cargo
    with_profile_project do |project_root, bin_directory|
      write_executable(bin_directory, 'perf', "#!/usr/bin/env bash\nexit 1\n")
      write_executable(bin_directory, 'cargo', "#!/usr/bin/env bash\ntouch cargo-was-run\n")

      _stdout, stderr, status = run_profile(project_root, bin_directory, 'profile-rust')

      refute_predicate status, :success?
      assert_includes stderr, 'requires access to Linux CPU performance events'
      refute File.exist?(File.join(project_root, 'ext', 'dry_validation_rust', 'cargo-was-run'))
    end
  end

  private

  def with_profile_project
    Dir.mktmpdir('dry-validation-rust-profile') do |project_root|
      scripts = %w[profile-ruby profile-rust]
      FileUtils.mkdir_p(File.join(project_root, 'script'))
      FileUtils.mkdir_p(File.join(project_root, 'ext', 'dry_validation_rust'))
      scripts.each do |script|
        FileUtils.cp(File.join(PROJECT_ROOT, 'script', script), File.join(project_root, 'script', script))
      end
      bin_directory = File.join(project_root, 'bin')
      FileUtils.mkdir_p(bin_directory)
      yield project_root, bin_directory
    end
  end

  def write_executable(directory, name, source)
    path = File.join(directory, name)
    File.write(path, source)
    FileUtils.chmod('+x', path)
  end

  def run_profile(project_root, bin_directory, script)
    ExecutableScriptTestHelper.capture(
      File.join(project_root, 'script', script),
      environment: { 'PATH' => "#{bin_directory}:#{ENV.fetch('PATH')}" }, chdir: project_root
    )
  end
end
