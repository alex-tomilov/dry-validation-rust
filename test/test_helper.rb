# frozen_string_literal: true

require 'rbconfig'
require 'open3'
require 'simplecov'
require 'simplecov-lcov'

SimpleCov.start do
  skip '/test/'
  group 'Lib', 'lib'
  formatter SimpleCov::Formatter::LcovFormatter
end
SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = File.join(SimpleCov.coverage_path, 'lcov.info')
end

PROJECT_ROOT = File.expand_path('..', __dir__)

module NativeExtensionTestHelper
  module_function

  def require_native_extension
    require 'dry/validation/rust'
  rescue LoadError => e
    raise unless e.message.include?('could not load its native extension')

    build_native_extension
    require 'dry/validation/rust'
  end

  def build_native_extension
    success = system(RbConfig.ruby, '-S', 'bundle', 'exec', 'rake', 'compile', chdir: PROJECT_ROOT)
    raise LoadError, 'dry-validation-rust native extension could not be rebuilt' unless success
  end
end

module ExecutableScriptTestHelper
  module_function

  def capture(script, *, environment: {}, **)
    Open3.capture3(environment, interpreter_for(script), script, *, **)
  end

  def interpreter_for(script)
    case File.open(script, &:gets).chomp
    when '#!/usr/bin/env ruby' then RbConfig.ruby
    when '#!/usr/bin/env bash' then 'bash'
    else
      raise ArgumentError, "unsupported script interpreter: #{script}"
    end
  end

  private_class_method :interpreter_for
end

require 'minitest/autorun'

NativeExtensionTestHelper.require_native_extension

module ContractTestHelpers
  def build_contract(&)
    Class.new(Dry::Validation::Rust::Contract, &)
  end
end

module Minitest
  class Test
    include ContractTestHelpers
  end
end
