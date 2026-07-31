# frozen_string_literal: true

require_relative 'test_helper'
require 'bundler'
require 'json'
require 'open3'

class BaselineFixtureTest < Minitest::Test
  FIXTURE_DIR = File.expand_path('fixtures/baseline', __dir__)

  def test_behavior_matches_baseline_fixtures
    baseline_cases.each do |name, runner|
      assert_equal fixture(name), runner.call, "baseline fixture #{name.inspect} changed"
    end
  end

  private

  def baseline_cases
    {
      'shallow_params' => method(:shallow_params),
      'nested_hash' => method(:nested_hash),
      'primitive_array' => method(:primitive_array),
      'array_of_hashes' => method(:array_of_hashes),
      'ruby_predicate' => method(:ruby_predicate),
      'rule_failure' => method(:rule_failure),
      'rule_each' => method(:rule_each),
      'options_and_context' => method(:options_and_context),
      'inherited_schema' => method(:inherited_schema),
      'imported_schema' => method(:imported_schema),
      'side_by_side_loading' => method(:side_by_side_loading),
      'exact_loading' => method(:exact_loading)
    }
  end

  def fixture(name)
    JSON.parse(File.read(File.join(FIXTURE_DIR, "#{name}.json")))
  end

  def result_payload(result)
    {
      'success' => result.success?,
      'output' => normalize(result.to_h),
      'errors' => normalize(result.errors.to_h),
      'context' => normalize(result.context)
    }
  end

  def normalize(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, child), normalized|
        normalized[key.nil? ? '__base__' : key.to_s] = normalize(child)
      end
    when Array
      value.map { |child| normalize(child) }
    when Symbol
      value.to_s
    else
      value
    end
  end

  def shallow_params
    contract = build_contract do
      params do
        required(:age).filled(:integer)
        required(:enabled).value(:bool)
        optional(:nickname).maybe(:string)
      end
    end

    result_payload(contract.new.call('age' => '42', 'enabled' => 'false', 'nickname' => ''))
  end

  def nested_hash
    contract = build_contract do
      params do
        required(:profile).hash do
          required(:name).filled(:string)
          required(:age).value(:integer)
        end
      end
    end

    result_payload(contract.new.call('profile' => { 'name' => '', 'age' => 'bad' }))
  end

  def primitive_array
    contract = build_contract do
      params { required(:scores).array(:integer) }
    end

    result_payload(contract.new.call('scores' => %w[1 bad 3]))
  end

  def array_of_hashes
    contract = build_contract do
      params do
        required(:people).array(:hash) do
          required(:id).value(:integer)
          required(:email).filled(:string)
        end
      end
    end

    result_payload(
      contract.new.call(
        'people' => [
          { 'id' => '7', 'email' => 'jane@example.org' },
          { 'id' => 'bad', 'email' => '' }
        ]
      )
    )
  end

  def ruby_predicate
    contract = build_contract do
      params { required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/) }
    end

    result_payload(contract.new.call('email' => 'bad'))
  end

  def rule_failure
    contract = build_contract do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure('must be an adult') if value < 18 }
    end

    result_payload(contract.new.call('age' => '17'))
  end

  def rule_each
    contract = build_contract do
      params { required(:numbers).array(:integer) }
      rule(:numbers).each do |index:|
        key.failure("item #{index} must be positive") if value <= 0
      end
    end

    result_payload(contract.new.call('numbers' => ['1', '0', '-2']))
  end

  def options_and_context
    repository = Object.new
    def repository.taken?(value) = value == 'used'

    contract = build_contract do
      option :repository
      params { required(:name).filled(:string) }
      rule(:name) do |context:|
        context[:checked] = true
        key.failure('is taken') if repository.taken?(value)
      end
    end

    result_payload(contract.new(repository: repository).call({ 'name' => 'used' }, { request_id: 7 }))
  end

  def inherited_schema
    parent = build_contract do
      params { required(:name).filled(:string) }
      rule(:name) { key.failure('is blocked') if value == 'blocked' }
    end
    child = Class.new(parent) do
      params { required(:age).value(:integer) }
      rule(:age) { key.failure('too young') if value < 18 }
    end

    result_payload(child.new.call('name' => 'blocked', 'age' => '10'))
  end

  def imported_schema
    address = Dry::Validation::Rust::Schema.Params do
      required(:city).filled(:string)
    end
    contract = build_contract do
      params(address) { required(:name).filled(:string) }
    end

    result_payload(contract.new.call('city' => '', 'name' => 'Alexey'))
  end

  def side_by_side_loading
    code = <<~RUBY
      require "json"
      require "dry/validation/rust"

      contract = Class.new(Dry::Validation::Rust::Contract) do
        params { required(:name).filled(:string) }
      end
      result = contract.new.call("name" => "Jane")

      puts JSON.generate(
        "contract_name" => Dry::Validation::Rust::Contract.name,
        "exact_alias_defined" => Dry::Validation.const_defined?(:Contract, false),
        "loaded_upstream_dry_validation" => Gem.loaded_specs.key?("dry-validation"),
        "success" => result.success?,
        "output" => result.to_h.transform_keys(&:to_s),
        "errors" => result.errors.to_h
      )
    RUBY

    run_isolated_json(code)
  end

  def exact_loading
    code = <<~RUBY
      require "json"
      require "dry/validation"

      contract = Class.new(Dry::Validation::Contract) do
        params { required(:age).value(:integer) }
      end
      result = contract.new.call("age" => "21")

      puts JSON.generate(
        "contract_alias" => Dry::Validation::Contract.name,
        "rust_alias" => Dry::Validation::Rust::Contract.name,
        "same_contract_class" => Dry::Validation::Contract.equal?(Dry::Validation::Rust::Contract),
        "loaded_upstream_dry_validation" => Gem.loaded_specs.key?("dry-validation"),
        "success" => result.success?,
        "output" => result.to_h.transform_keys(&:to_s),
        "errors" => result.errors.to_h
      )
    RUBY

    run_isolated_json(code)
  end

  def run_isolated_json(code)
    stdout, stderr, status = Bundler.with_unbundled_env do
      Open3.capture3(
        RbConfig.ruby,
        "-I#{File.join(PROJECT_ROOT, 'lib')}",
        '-e',
        code
      )
    end
    assert status.success?, stderr
    JSON.parse(stdout)
  end
end
