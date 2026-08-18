# frozen_string_literal: true

require_relative 'test_helper'

class PathTrieTest < Minitest::Test
  def test_empty_trie_has_no_prefixes
    refute Dry::Validation::Rust::PathTrie.new.prefix?([:profile])
    refute Dry::Validation::Rust::PathTrie.new.prefix?([])
  end

  def test_exact_path_matches
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add(%i[profile email])
    trie.add(%i[profile name])

    assert trie.prefix?(%i[profile email])
  end

  def test_path_with_an_error_prefix_matches
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add([:profile])

    assert trie.prefix?(%i[profile email])
  end

  def test_path_that_is_a_prefix_of_a_stored_error_matches
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add(%i[profile email])

    assert trie.prefix?([:profile])
  end

  def test_non_matching_path_does_not_match
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add(%i[profile email])

    refute trie.prefix?(%i[profile name])
  end

  def test_array_indexes_are_path_parts
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add([:users, 1, :email])

    assert trie.prefix?([:users, 1, :email, :domain])
    refute trie.prefix?([:users, 0, :email])
  end

  def test_freeze_prevents_paths_from_being_added
    trie = Dry::Validation::Rust::PathTrie.new
    trie.add(%i[profile email])
    trie.freeze

    assert_predicate trie, :frozen?
    assert_raises(FrozenError) { trie.add(%i[profile name]) }
  end

  def test_equal_tries_compare_by_paths
    left = Dry::Validation::Rust::PathTrie.new
    right = Dry::Validation::Rust::PathTrie.new
    left.add(%i[profile email])
    right.add(%i[profile email])

    assert_equal left, right
    refute_equal left, Object.new
  end
end
