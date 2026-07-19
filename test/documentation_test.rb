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

  def test_readme_documents_build_week_collaboration_and_evidence
    readme = read_doc("README.md")
    normalized_readme = readme.gsub(/\s+/, " ")

    assert_includes readme, "## OpenAI Build Week 2026"
    assert_includes readme, "GPT-5.6 was used as an architecture and repository-review partner"
    assert_includes readme, "Codex then helped inspect the repository"
    assert_includes normalized_readme, "The human author retained"
    assert_includes readme, "[Build Week evidence ledger](docs/BUILD_WEEK_2026_EVIDENCE.md)"
    assert_includes readme, "does not require an OpenAI API key"
  end

  def test_build_week_evidence_is_judge_facing_and_reproducible
    evidence = read_doc("docs/BUILD_WEEK_2026_EVIDENCE.md")

    assert_includes evidence, "## 5. Codex session and commit evidence"
    assert_includes evidence, "## 7. Independent verification"
    assert_includes evidence, "d59086bee12780a4ef962e3ce63450b7bd30c2dd"
    assert_includes evidence, "65dd9cd7641d66af73eb8af82086aaf0790857d0"
    assert_includes evidence, "script/build-week-evidence"
    refute_includes evidence, "Current evidence mapping to complete"
    refute_includes evidence, "Evidence maintenance procedure"
    refute_includes evidence, "Before final submission"
    refute_match(/<PRIMARY_CODEX_FEEDBACK_SESSION_ID>|<SECONDARY_SESSION_ID_OR_REMOVE>/, evidence)
  end

  def test_compatibility_target_uses_pinned_releases
    compatibility = read_doc("docs/COMPATIBILITY.md")

    refute_includes compatibility, "current upstream main"
    assert_includes compatibility, "`dry-validation` 1.11.1"
    assert_includes compatibility, "`dry-schema` 1.16.0"
  end

  private

  def read_doc(path)
    File.read(File.join(PROJECT_ROOT, path))
  end
end
