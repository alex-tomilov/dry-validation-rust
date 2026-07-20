# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

class CleanRoomVerificationTest < Minitest::Test
  SCRIPT = File.join(PROJECT_ROOT, "script", "clean-room-verify")
  PROJECT_TMP = File.join(PROJECT_ROOT, "tmp")

  def setup
    FileUtils.mkdir_p(PROJECT_TMP)
  end

  def test_help_documents_modes_and_safety_contract
    stdout, stderr, status = Open3.capture3(SCRIPT, "--help", chdir: Dir.tmpdir)

    assert status.success?, stderr
    assert_empty stderr
    %w[--docker-only --native-only --package-only --all --image --output].each do |option|
      assert_includes stdout, option
    end
    assert_includes stdout, "Existing output"
    assert_includes stdout, "does not install host packages"
  end

  def test_unavailable_docker_is_reported_as_skipped
    with_fake_docker(<<~'SH') do |bin_dir|
      #!/usr/bin/env bash
      exit 127
    SH
      Dir.mktmpdir("dvr-clean-room-output", PROJECT_TMP) do |parent|
        output = File.join(parent, "evidence")
        stdout, stderr, status = run_script(bin_dir, "--docker-only", "--output", relative_output(output))

        assert status.success?, stderr
        assert_includes stdout, "local_docker"
        assert_includes stdout, "SKIPPED"
        summary = File.read(File.join(output, "summary.tsv"))
        assert_includes summary, "local_docker\tSKIPPED\tDocker daemon is unavailable"
        assert_includes summary, "public_image\tSKIPPED\tNo public image reference supplied"
      end
    end
  end

  def test_output_refuses_symlinked_parent_below_tmp
    Dir.mktmpdir("dvr-clean-room-output", PROJECT_TMP) do |parent|
      Dir.mktmpdir("dvr-clean-room-outside") do |outside|
        link = File.join(parent, "linked")
        File.symlink(outside, link)
        output = File.join(link, "evidence")

        _stdout, stderr, status = Open3.capture3(
          SCRIPT,
          "--docker-only",
          "--output",
          relative_output(output),
          chdir: Dir.tmpdir
        )

        refute status.success?
        assert_includes stderr, "Refusing a symlinked output path component"
        refute_path_exists File.join(outside, "evidence")
      end
    end
  end

  def test_requested_failure_is_nonzero_and_log_is_redacted
    with_fake_docker(<<~'SH') do |bin_dir|
      #!/usr/bin/env bash
      case "$1" in
        info) exit 0 ;;
        version) printf '%s\n' 'docker_client=fake docker_server=fake' ;;
        build)
          printf '%s\n' 'API_TOKEN=supersecret ghp_abcdefghijklmnopqrstuvwxyz123456'
          printf 'home=%s\n' "$HOME"
          exit 42
          ;;
        image) exit 0 ;;
        *) exit 0 ;;
      esac
    SH
      Dir.mktmpdir("dvr-clean-room-output", PROJECT_TMP) do |parent|
        output = File.join(parent, "evidence")
        _stdout, _stderr, status = run_script(bin_dir, "--docker-only", "--output", relative_output(output))

        refute status.success?
        summary = File.read(File.join(output, "summary.tsv"))
        assert_includes summary, "local_docker_build\tFAILED"
        log = File.read(File.join(output, "logs", "local_docker_build.log"))
        assert_includes log, "API_TOKEN=<REDACTED>"
        assert_includes log, "<REDACTED_TOKEN>"
        assert_includes log, "<PROJECT_ROOT>"
        assert_includes log, "home=<HOME>"
        refute_includes log, "supersecret"
        refute_includes log, "ghp_abcdefghijklmnopqrstuvwxyz123456"
        refute_includes log, PROJECT_ROOT
        refute_includes log, ENV.fetch("HOME")
      end
    end
  end

  def test_script_uses_no_cache_and_avoids_privileged_or_environment_dumping_commands
    source = File.read(SCRIPT)

    assert_includes source, "--no-cache --pull --platform"
    assert_includes source, "DOCKER_CONFIG"
    docker_info_line = source.lines.find { |line| line.include?("docker info") }
    assert docker_info_line.rstrip.end_with?("\\"), docker_info_line
    assert_includes source, "--format 'server={{.ServerVersion}}"
    refute_match(/docker info\s*(?:;|$)/, source)
    assert_includes source, "RepoDigests"
    assert_includes source, "BUNDLE_IGNORE_CONFIG=1"
    assert_includes source, "ruby bundle rustc cargo make cc"
    assert_includes source, "bundle exec rake package:audit"
    assert_includes source, "script/docker-smoke"
    refute_match(/\bsudo\b/, source.lines.reject { |line| line.include?("does not install host packages") }.join)
    refute_match(/\b(?:printenv|env)\s*(?:$|[|>])/, source)
  end

  private

  def with_fake_docker(source)
    Dir.mktmpdir("dvr-clean-room-bin") do |bin_dir|
      docker = File.join(bin_dir, "docker")
      File.write(docker, source)
      FileUtils.chmod(0o755, docker)
      yield bin_dir
    end
  end

  def run_script(bin_dir, *arguments)
    Open3.capture3(
      {"PATH" => "#{bin_dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}"},
      SCRIPT,
      *arguments,
      chdir: Dir.tmpdir
    )
  end

  def relative_output(path)
    Pathname.new(path).relative_path_from(Pathname.new(PROJECT_ROOT)).to_s
  end
end
