# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"

class DifferentialCompatibilityTest < Minitest::Test
  UPSTREAM_VERSION = "1.11.1"

  RUNNER = <<~'RUBY'
    require "json"

    mode, encoded = ARGV
    payload = JSON.parse(encoded)
    if mode == "upstream"
      gem "dry-validation", ENV.fetch("DRY_VALIDATION_UPSTREAM_VERSION")
    end
    require "dry/validation"

    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key.nil? ? "__base__" : key.to_s] = normalize(child) }
      when Array then value.map { |child| normalize(child) }
      when Symbol then { "__symbol__" => value.to_s }
      else value
      end
    end

    def classes(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key.nil? ? "__base__" : key.to_s] = classes(child) }
      when Array then value.map { |child| classes(child) }
      else value.class.name
      end
    end

    begin
      trace = []
      contract = eval(payload.fetch("source"), binding, "differential-case.rb", 1)
      result = contract.new.call(payload.fetch("input"))
      puts JSON.generate(
        "engine" => mode,
        "dry_validation_version" => Gem.loaded_specs["dry-validation"]&.version&.to_s,
        "success" => result.success?,
        "output" => normalize(result.to_h),
        "classes" => classes(result.to_h),
        "errors" => normalize(result.errors.to_h),
        "trace" => trace
      )
    rescue StandardError => error
      puts JSON.generate(
        "engine" => mode,
        "dry_validation_version" => Gem.loaded_specs["dry-validation"]&.version&.to_s,
        "exception" => { "class" => error.class.name, "message" => error.message }
      )
    end
  RUBY

  def test_schema_and_rule_subset_matches_pinned_upstream_in_isolated_processes
    differential_cases.each do |fixture|
      upstream = run_case("upstream", fixture)
      rust = run_case("rust", fixture)

      assert_equal UPSTREAM_VERSION, upstream.fetch("dry_validation_version"), fixture.fetch(:name)
      assert_nil rust.fetch("dry_validation_version"), fixture.fetch(:name)
      assert_equal comparable_payload(upstream), comparable_payload(rust), fixture.fetch(:name)
    end
  end

  def test_recognized_unsupported_constructs_fail_explicitly_and_deterministically
    unsupported_cases.each do |fixture|
      first = run_rust_source(fixture.fetch(:source), fixture.fetch(:input, {}))
      second = run_rust_source(fixture.fetch(:source), fixture.fetch(:input, {}))

      assert_equal first, second, fixture.fetch(:name)
      exception = first.fetch("exception")
      assert_equal "Dry::Validation::Rust::UnsupportedFeatureError", exception.fetch("class"), fixture.fetch(:name)
      assert_match fixture.fetch(:message), exception.fetch("message"), fixture.fetch(:name)
    end
  end

  private

  def run_case(mode, fixture)
    stdout, stderr, status = capture_isolated(
      { "DRY_VALIDATION_UPSTREAM_VERSION" => UPSTREAM_VERSION },
      RbConfig.ruby, *ruby_load_path(mode), "-e", RUNNER, mode,
      JSON.generate("source" => fixture.fetch(:source), "input" => fixture.fetch(:input))
    )
    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def run_rust_source(source, input = {})
    stdout, stderr, status = capture_isolated(
      {}, RbConfig.ruby, *ruby_load_path("rust"), "-e", RUNNER, "rust",
      JSON.generate("source" => source, "input" => input)
    )
    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def ruby_load_path(mode)
    return [] if mode == "upstream"

    ["-I#{File.join(PROJECT_ROOT, "lib")}"]
  end

  def capture_isolated(environment, *command)
    Bundler.with_unbundled_env { Open3.capture3(environment, *command) }
  end

  def comparable_payload(payload)
    payload.reject { |key, _| %w[engine dry_validation_version].include?(key) }
  end

  def differential_cases
    [
      schema_case("required scalar succeeds", 'params { required(:name).value(:string) }', { "name" => "Jane" }),
      schema_case("required scalar missing", 'params { required(:name).value(:string) }', {}),
      schema_case("optional scalar omitted", 'params { optional(:name).value(:string) }', {}),
      schema_case("optional scalar supplied", 'params { optional(:name).value(:string) }', { "name" => "Jane" }),
      schema_case("integer coercion", 'params { required(:age).value(:integer) }', { "age" => "42" }),
      schema_case("integer coercion failure", 'params { required(:age).value(:integer) }', { "age" => "forty-two" }),
      schema_case("boolean coercion", 'params { required(:enabled).value(:bool) }', { "enabled" => "false" }),
      schema_case("filled rejects blank string", 'params { required(:name).filled(:string) }', { "name" => "" }),
      schema_case("maybe converts blank params string", 'params { required(:name).maybe(:string) }', { "name" => "" }),
      schema_case("nested hash succeeds", 'params { required(:profile).hash { required(:age).value(:integer) } }', { "profile" => { "age" => "42" } }),
      schema_case("nested hash missing key", 'params { required(:profile).hash { required(:age).value(:integer) } }', { "profile" => {} }),
      schema_case("primitive array succeeds", 'params { required(:scores).array(:integer) }', { "scores" => ["1", "2"] }),
      schema_case("primitive array coercion failure", 'params { required(:scores).array(:integer) }', { "scores" => ["1", "bad"] }),
      schema_case("array of hashes succeeds", 'params { required(:people).array(:hash) { required(:id).value(:integer) } }', { "people" => [{ "id" => "7" }] }),
      schema_case("array of hashes invalid", 'params { required(:people).array(:hash) { required(:id).value(:integer) } }', { "people" => [{ "id" => "bad" }] }),
      schema_case("greater than predicate", 'params { required(:age).value(:integer, gt?: 18) }', { "age" => "18" }),
      schema_case("minimum size predicate", 'params { required(:name).value(:string, min_size?: 3) }', { "name" => "Al" }),
      schema_case("format predicate", 'params { required(:email).value(:string, format?: /\\A[^@]+@[^@]+\\z/) }', { "email" => "invalid" }),
      schema_case("included in predicate", 'params { required(:role).value(:string, included_in?: %w[admin user]) }', { "role" => "guest" }),
      schema_case("json does not coerce", 'json { required(:age).value(:integer) }', { "age" => "42" }),
      schema_case("schema retains symbol keys", 'schema { required(:age).value(:integer) }', { age: 42 }),
      rule_case("single key rule", 'params { required(:age).value(:integer) }; rule(:age) { key.failure("must be adult") if value < 18 }', { "age" => "17" }),
      rule_case("multi key rule", 'params { required(:start).value(:integer); required(:finish).value(:integer) }; rule(:start, :finish) { key(:finish).failure("must follow start") if values[:finish] < values[:start] }', { "start" => "5", "finish" => "4" }),
      rule_case("base rule failure", 'params { required(:age).value(:integer) }; rule(:age) { base.failure("blocked") if value == 0 }', { "age" => "0" }),
      rule_case("rule skips after schema failure", 'params { required(:age).value(:integer) }; rule(:age) { trace << "ran"; key.failure("must be adult") if value < 18 }', { "age" => "bad" }),
      rule_case("rule trace on valid schema", 'params { required(:age).value(:integer) }; rule(:age) { trace << "ran"; key.failure("must be adult") if value < 18 }', { "age" => "17" }),
      rule_case("rule exception propagates", 'params { required(:age).value(:integer) }; rule(:age) { raise ArgumentError, "rule exploded" }', { "age" => "17" })
    ]
  end

  def unsupported_cases
    [
      { name: "unsupported type object", source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(Object.new) } }', message: /unsupported type or predicate specification: Object/ },
      { name: "unknown predicate", source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(:integer, unknown?: 1) } }', input: { "age" => "1" }, message: /predicate :unknown/ },
      { name: "strict key configuration", source: 'Class.new(Dry::Validation::Contract) { config.validate_keys = true }', message: /validate_keys/ },
      { name: "predicate composition", source: 'Class.new(Dry::Validation::Contract) { params { required(:age).value(:integer) { gt? 18 } } }', message: /predicate composition/ }
    ]
  end

  def schema_case(name, declaration, input)
    { name: name, source: "Class.new(Dry::Validation::Contract) do\n#{declaration}\nend", input: input }
  end

  def rule_case(name, body, input)
    { name: name, source: "Class.new(Dry::Validation::Contract) do\n#{body}\nend", input: input }
  end
end
