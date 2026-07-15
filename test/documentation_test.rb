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
