# frozen_string_literal: true

require "minitest/autorun"
require "dry/validation/rust"

module ContractTestHelpers
  def build_contract(&block)
    Class.new(Dry::Validation::Rust::Contract, &block)
  end
end

class Minitest::Test
  include ContractTestHelpers
end
