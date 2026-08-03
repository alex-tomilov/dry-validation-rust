# frozen_string_literal: true

require_relative 'test_helper'

class PathTest < Minitest::Test
  def test_fetch_preserves_values_and_returns_the_fallback_for_missing_paths
    data = { user: { names: ['Ada'] } }
    fallback = Object.new

    assert_equal 'Ada', Dry::Validation::Rust::Path.fetch(data, %i[user names] + [0])
    assert_same data, Dry::Validation::Rust::Path.fetch(data, nil)
    assert_same fallback, Dry::Validation::Rust::Path.fetch(data, %i[user missing], fallback)
    assert_same fallback, Dry::Validation::Rust::Path.fetch(data, %i[user names] + [-1], fallback)
    assert_same fallback, Dry::Validation::Rust::Path.fetch(data, %i[user names] + [1], fallback)
  end
end
