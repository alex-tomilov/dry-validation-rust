# frozen_string_literal: true

require "rbconfig"

PROJECT_ROOT = File.expand_path("..", __dir__)

module NativeExtensionTestHelper
  module_function

  def require_native_extension
    require "dry/validation/rust"
  rescue LoadError => error
    raise unless error.message.include?("could not load its native extension")

    build_native_extension
    require "dry/validation/rust"
  end

  def build_native_extension
    success = system(RbConfig.ruby, "-S", "bundle", "exec", "rake", "compile", chdir: PROJECT_ROOT)
    raise LoadError, "dry-validation-rust native extension could not be rebuilt" unless success
  end
end

require "minitest/autorun"

NativeExtensionTestHelper.require_native_extension

module ContractTestHelpers
  def build_contract(&block)
    Class.new(Dry::Validation::Rust::Contract, &block)
  end
end

class Minitest::Test
  include ContractTestHelpers
end
