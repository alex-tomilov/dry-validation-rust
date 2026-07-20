# frozen_string_literal: true

require_relative "test_helper"

class DocumentationTest < Minitest::Test
  def test_support_matrix_pins_alpha_compatibility_reference
    support_matrix = read_doc("docs/SUPPORT_MATRIX.md")

    assert_includes support_matrix, "`dry-validation` 1.11.1"
    assert_includes support_matrix, "`dry-schema` 1.16.0"
    assert_includes support_matrix, "Dry::Validation::Rust::Contract"
  end

  def test_readme_presents_safe_api_before_exact_shim
    readme = read_doc("README.md")

    safe_heading = readme.index("## Primary safe API")
    exact_heading = readme.index("## Exact compatibility shim")

    refute_nil safe_heading
    refute_nil exact_heading
    assert_operator safe_heading, :<, exact_heading
    assert_includes readme, "Collision warning"
    assert_includes readme, "docs/SUPPORT_MATRIX.md"
    assert_includes readme, "docs/COMPATIBILITY.md"
  end

  def test_readme_leads_judges_from_product_to_verified_paths
    readme = read_doc("README.md")

    headings = [
      "## Try it with Docker",
      "## Expected demo behavior",
      "## Why hybrid?",
      "## Primary safe API",
      "## Supported highlights",
      "## Benchmark evidence",
      "## OpenAI Build Week 2026",
      "## Building from source",
      "## Verification and contributing",
      "## Current limitations and performance caveats",
      "## Exact compatibility shim",
      "## Documentation",
      "## License and non-affiliation"
    ]

    positions = headings.map { |heading| readme.index(heading) }
    refute_includes positions, nil
    assert_equal positions.sort, positions
    assert_operator readme.index("**Status: feasibility prototype"), :<, positions.first
    assert_includes readme, "docker build --pull --platform linux/amd64 -t dry-validation-rust:local"
    assert_includes readme, "docker run --rm --network none --platform linux/amd64 dry-validation-rust:local"
    assert_includes readme, "competition tag is not anonymously accessible"
    assert_includes readme, "Demo complete: 10 checks passed"
    assert_includes readme, "The clean-commit full evidence package has not yet been generated"
    refute_includes readme, "validations/s"
  end

  def test_readme_documents_build_week_collaboration_and_evidence
    readme = read_doc("README.md")
    normalized_readme = readme.gsub(/\s+/, " ")

    assert_includes readme, "## OpenAI Build Week 2026"
    assert_includes readme, "GPT-5.6 was used as an architecture and repository-review partner"
    assert_includes readme, "Codex helped inspect the repository"
    assert_includes normalized_readme, "The human author retained"
    assert_includes readme, "[Build Week evidence ledger](docs/BUILD_WEEK_2026_EVIDENCE.md)"
    assert_includes readme, "[Build Week narrative](docs/BUILD_WEEK_2026.md)"
    assert_includes readme, "<PRIMARY_CODEX_FEEDBACK_SESSION_ID>"
    assert_includes normalized_readme, "does not require an OpenAI API key"
    refute_includes readme, "<PUBLIC_YOUTUBE_DEMO_URL>"
  end

  def test_build_week_evidence_is_judge_facing_and_reproducible
    evidence = read_doc("docs/BUILD_WEEK_2026_EVIDENCE.md")

    assert_includes evidence, "## 5. Codex session and commit evidence"
    assert_includes evidence, "## 7. Independent verification"
    assert_includes evidence, "d59086bee12780a4ef962e3ce63450b7bd30c2dd"
    assert_includes evidence, "65dd9cd7641d66af73eb8af82086aaf0790857d0"
    assert_includes evidence, "0c189d252f478058963b53b4f0932d7c3461e59a"
    assert_includes evidence, "script/build-week-evidence"
    refute_includes evidence, "Current evidence mapping to complete"
    refute_includes evidence, "Evidence maintenance procedure"
    refute_includes evidence, "Before final submission"
    refute_match(/<PRIMARY_CODEX_FEEDBACK_SESSION_ID>|<SECONDARY_SESSION_ID_OR_REMOVE>/, evidence)
  end

  def test_build_week_narrative_separates_roles_and_flags_blockers
    narrative = read_doc("docs/BUILD_WEEK_2026.md")
    audit_helper = read_doc("script/build-week-evidence")

    assert_includes narrative, "## Pre-existing foundation"
    assert_includes narrative, "## Meaningful Build Week additions"
    assert_includes narrative, "## How GPT-5.6 contributed"
    assert_includes narrative, "## How Codex contributed"
    assert_includes narrative, "## Human decisions"
    assert_includes narrative, "## Runtime independence"
    assert_includes narrative, "does not require an\nOpenAI API key"
    assert_includes narrative, "https://chatgpt.com/share/6a5c38e4-c380-83ed-a4cb-ac221d42d905"
    assert_includes narrative, "<PRIMARY_CODEX_FEEDBACK_SESSION_ID>"
    assert_includes narrative, "<PUBLIC_YOUTUBE_DEMO_URL>"
    assert_includes narrative, "Submission blockers"
    assert_includes audit_helper, "docs/BUILD_WEEK_2026.md"
  end

  def test_every_relative_readme_link_resolves
    readme = read_doc("README.md")
    targets = readme.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten
    relative_targets = targets.reject do |target|
      target.start_with?("http://", "https://", "#")
    end

    relative_targets.each do |target|
      path = target.split("#", 2).first
      assert File.exist?(File.join(PROJECT_ROOT, path)), "missing README link target: #{target}"
    end
  end

  def test_compatibility_target_uses_pinned_releases
    compatibility = read_doc("docs/COMPATIBILITY.md")

    refute_includes compatibility, "current upstream main"
    assert_includes compatibility, "`dry-validation` 1.11.1"
    assert_includes compatibility, "`dry-schema` 1.16.0"
  end

  def test_clean_room_matrix_distinguishes_observed_and_unverified_paths
    documentation = read_doc("docs/CLEAN_ROOM_VERIFICATION.md")
    support_matrix = read_doc("docs/SUPPORT_MATRIX.md")
    readme = read_doc("README.md")

    assert_includes documentation, "| Public prebuilt image |"
    assert_includes documentation, "**UNAVAILABLE**"
    assert_includes documentation, "| Local Docker build |"
    assert_includes documentation, "**PASSED**"
    assert_includes documentation, "| Native Linux source build |"
    assert_includes documentation, "| Native macOS source build |"
    assert_includes documentation, "**UNVERIFIED HERE**"
    assert_includes documentation, "| Source gem isolated install |"
    assert_includes documentation, "| Native Windows |"
    assert_includes documentation, "| JRuby / TruffleRuby |"
    assert_includes documentation, "--no-cache"
    assert_includes documentation, "RepoDigest"
    assert_includes documentation, "`SKIPPED`, never as `PASSED`"
    assert_includes support_matrix, "Linux x86-64 source verified"
    assert_includes support_matrix, "macOS is a source-build CI target"
    assert_includes readme, "[Clean-room verification](docs/CLEAN_ROOM_VERIFICATION.md)"
  end

  def test_video_package_is_complete_truthful_and_privacy_safe
    paths = %w[
      docs/demo/VIDEO_SCRIPT.md
      docs/demo/SHOT_LIST.md
      docs/demo/TERMINAL_COMMANDS.md
      docs/demo/RECORDING_CHECKLIST.md
      docs/demo/ASSET_MANIFEST.md
    ]
    package = paths.to_h { |path| [path, read_doc(path)] }
    script = package.fetch("docs/demo/VIDEO_SCRIPT.md")
    shots = package.fetch("docs/demo/SHOT_LIST.md")
    commands = package.fetch("docs/demo/TERMINAL_COMMANDS.md")
    checklist = package.fetch("docs/demo/RECORDING_CHECKLIST.md")
    assets = package.fetch("docs/demo/ASSET_MANIFEST.md")

    %w[0:00 0:15 0:30 1:15 1:35 2:12 2:38 2:48].each do |timestamp|
      assert_includes script, timestamp
    end
    assert_includes script, "<MM:SS on YYYY-MM-DD; replace before submission>"
    assert_includes script, "full package is not ready"
    assert_includes script, "remains under the GVL"
    assert_includes script, "runtime is deterministic Ruby and Rust"
    assert_includes script, "I retained the Ruby-Rust boundary"
    voiceover = script.scan(/\*\*Voiceover:\*\*\n\n(.*?)(?=\n## |\z)/m).flatten.join(" ")
    voiceover_words = voiceover.scan(/[[:alnum:]][[:alnum:]’'`.\/-]*/).length
    assert_operator voiceover_words, :>=, 350
    assert_operator voiceover_words, :<=, 400
    refute_match(/\b\d+(?:\.\d+)?x\b/, script)
    refute_includes script, "full compatibility"
    refute_includes script, "all validation in Rust"
    refute_includes script, "GPT-5.6 is integrated into the engine"

    assert_includes shots, "Backup:"
    assert_includes shots, "maximum 45 seconds"
    assert_includes shots, "docs/BUILD_WEEK_2026.md:70-101"
    refute_includes shots, "docs/BUILD_WEEK_2026_EVIDENCE.md:115-164"
    assert_includes shots, "I built this verified local image"
    assert_includes shots, "The harness compares Rust with pinned upstream"
    assert_includes commands, "docker build --pull --platform linux/amd64"
    assert_includes commands, "docker run --rm --network none --platform linux/amd64"
    assert_includes commands, "sed -n '1,8p' benchmark/results/build-week-2026/README.md"
    assert_includes commands, "script/build-week-evidence | sed -n '1,9p'"
    refute_includes commands, "ghcr.io/alex-tomilov"
    refute_match(%r{/home/|/Users/}, commands)
    refute_match(/github_pat_|gh[pousr]_|sk-[A-Za-z0-9]/, commands)

    assert_includes checklist, "https://openai.devpost.com/rules"
    assert_includes checklist, "https://openai.devpost.com/details/faqs"
    assert_includes checklist, "under 3:00"
    assert_includes checklist, "publicly visible"
    assert_includes checklist, "Audio/voiceover"
    assert_includes checklist, "public YouTube URL"

    assert_includes assets, "MANUAL CAPTURE REQUIRED"
    assert_includes assets, "primary `/feedback` ID still pending"
    assert_includes assets, "no performance figure approved"
    assert_includes read_doc("README.md"), "[Build Week video package](docs/demo/VIDEO_SCRIPT.md)"
  end

  private

  def read_doc(path)
    File.read(File.join(PROJECT_ROOT, path))
  end
end
