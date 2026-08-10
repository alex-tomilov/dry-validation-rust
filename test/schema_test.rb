# frozen_string_literal: true

require_relative 'test_helper'
require 'dry/types'
require 'tempfile'

class SchemaTest < Minitest::Test
  TRAVERSAL_DEPTH_LIMIT = 128

  def test_processor_hooks_sanitize_before_validation_and_transform_output_afterwards
    hook_inputs = []
    contract = build_contract do
      params do
        before(:value_coercer) do |input|
          hook_inputs << input.dup
          input.merge('name' => input.fetch('name').strip)
        end
        before(:value_coercer) { |input| input.merge('name' => "#{input.fetch('name')}!") }
        after(:value_coercer) do |output|
          hook_inputs << output.dup
          output.merge(name: output.fetch(:name).upcase)
        end

        required(:name).value(:string, min_size?: 5)
      end
    end

    result = contract.new.call('name' => ' Jane ')

    assert result.success?
    assert_equal({ name: 'JANE!' }, result.to_h)
    assert_equal([{ 'name' => ' Jane ' }, { name: 'Jane!' }], hook_inputs)
  end

  def test_processor_hooks_keep_the_current_hash_when_a_hook_mutates_it_without_returning_a_hash
    contract = build_contract do
      params do
        before(:value_coercer) { |input| input['age'] = input.fetch('age').strip }
        after(:value_coercer) { |output| output[:age] += 1 }
        required(:age).value(:integer)
      end
    end

    assert_equal({ age: 43 }, contract.new.call('age' => ' 42 ').to_h)
  end

  def test_before_processor_hooks_receive_a_shallow_duplicate_of_input
    contract = build_contract do
      params do
        before(:value_coercer) { |input| input.fetch('account')['name'] = 'Jane' }
        required(:account).hash { required(:name).value(:string) }
      end
    end
    input = { 'account' => { 'name' => 'John' } }

    result = contract.new.call(input)

    assert result.success?
    assert_equal({ account: { name: 'Jane' } }, result.to_h)
    assert_equal({ 'account' => { 'name' => 'Jane' } }, input)
  end

  def test_processor_hooks_reject_unknown_stages_and_missing_blocks
    unknown_stage = assert_raises(ArgumentError) do
      build_contract { params { before(:coerce) { |input| input } } }
    end
    missing_block = assert_raises(ArgumentError) do
      build_contract { params { after(:value_coercer) } }
    end

    assert_equal(
      'Undefined step name :coerce. Available names: [:value_coercer]',
      unknown_stage.message
    )
    assert_equal 'processor hooks require a block', missing_block.message
  end

  def test_yaml_message_backend_uses_load_paths_and_interpolates_predicate_tokens
    with_message_file(<<~YAML) do |path|
      es:
        dry_validation:
          errors:
            gt?: "debe ser mayor que %<num>s"
            type: "debe ser %<type>s"
    YAML
      contract = build_contract do
        config.messages.default_locale = :es
        config.messages.top_namespace = :dry_validation
        config.messages.load_paths << path
        params { required(:age).value(:integer, gt?: 18) }
      end

      assert_equal({ age: ['debe ser mayor que 18'] }, contract.new.call(age: '18').errors.to_h)
      assert_equal({ age: ['debe ser integer'] }, contract.new.call(age: 'invalid').errors.to_h)
    end
  end

  def test_i18n_message_backend_loads_paths_and_delegates_interpolation
    skip 'i18n is not installed' if Gem::Specification.find_all_by_name('i18n').empty?

    with_message_file(<<~YAML) do |path|
      fr:
        dry_validation:
          errors:
            included_in?: "doit être %<list>s"
    YAML
      contract = build_contract do
        config.messages.backend = :i18n
        config.messages.default_locale = :fr
        config.messages.top_namespace = :dry_validation
        config.messages.load_paths << path
        params { required(:role).value(:string, included_in?: %w[admin editor]) }
      end

      assert_equal({ role: ['doit être admin, editor'] }, contract.new.call(role: 'reader').errors.to_h)
    end
  end

  def test_yaml_message_backend_interpolates_range_predicate_tokens
    with_message_file(<<~YAML) do |path|
      en:
        dry_validation:
          errors:
            included_in?: "must be between %<left>s and %<right>s"
    YAML
      contract = build_contract do
        config.messages.load_paths << path
        params { required(:rating).value(:integer, included_in?: 3..5) }
      end

      assert_equal({ rating: ['must be between 3 and 5'] }, contract.new.call(rating: 6).errors.to_h)
    end
  end

  def test_message_backend_rejects_unknown_identifiers
    error = assert_raises(ArgumentError) do
      build_contract do
        config.messages.backend = :database
        params { required(:name).value(:string) }
      end
    end

    assert_equal '+database+ is not a valid messages identifier', error.message
  end

  def test_schema_at_the_nesting_limit_preserves_the_entire_output
    schema = Dry::Validation::Rust::Schema.Params(&nested_schema(TRAVERSAL_DEPTH_LIMIT))

    result = schema.call(nested_input(TRAVERSAL_DEPTH_LIMIT))

    assert result.success?
    assert_equal nested_output(TRAVERSAL_DEPTH_LIMIT), result.to_h
  end

  def test_schema_above_the_nesting_limit_reports_a_depth_error
    nesting_depth = TRAVERSAL_DEPTH_LIMIT + 1
    schema = Dry::Validation::Rust::Schema.Params(&nested_schema(nesting_depth))

    result = schema.call(nested_input(nesting_depth))
    error = result.messages.first

    assert_equal :depth, error.code
    assert_equal "schema nesting depth exceeds limit (#{TRAVERSAL_DEPTH_LIMIT})", error.text
    assert_equal (0..TRAVERSAL_DEPTH_LIMIT).map { |level| :"level_#{level}" }, error.path
    assert_equal nested_output(TRAVERSAL_DEPTH_LIMIT, {}), result.to_h
  end

  def test_native_engine_returns_structured_errors
    schema = Dry::Validation::Rust::Schema.Params { required(:age).value(:integer) }

    _output, native_errors = schema.engine.call(age: 'invalid')

    assert_equal [{ path: [:age], code: :type, text: 'must be an integer' }], native_errors
  end

  def test_native_engine_supplies_the_unexpected_key_error_text
    schema = Dry::Validation::Rust::Schema.new(
      mode: :params,
      fields: [],
      validate_keys: true
    )

    _output, native_errors = schema.engine.call(unexpected: true)

    assert_equal [{ path: [:unexpected], code: :unexpected_key, text: 'is not allowed' }], native_errors
  end

  def test_native_engine_keeps_date_class_lookup_from_initialization
    schema = Dry::Validation::Rust::Schema.Params { required(:value).value(:date) }
    date_class = Object.const_get(:Date)

    Object.send(:remove_const, :Date)
    output, native_errors = schema.engine.call(value: '2026-08-03')

    assert_equal({ value: date_class.new(2026, 8, 3) }, output)
    assert_empty native_errors
  ensure
    Object.const_set(:Date, date_class) unless Object.const_defined?(:Date, false)
  end

  def test_params_coerces_keys_and_scalar_values
    contract = build_contract do
      params do
        required(:age).filled(:integer)
        required(:ratio).value(:float)
        required(:enabled).value(:bool)
        required(:role).value(:symbol)
        optional(:nickname).maybe(:string)
      end
    end

    result = contract.new.call(
      'age' => '42', 'ratio' => '1.5', 'enabled' => 'false',
      'role' => 'admin', 'nickname' => '', 'ignored' => 'value'
    )

    assert result.success?
    assert_equal({ age: 42, ratio: 1.5, enabled: false, role: :admin, nickname: nil }, result.to_h)
  end

  def test_params_integer_coercion_preserves_ruby_syntax_and_bignum_fallbacks
    contract = build_contract do
      params { required(:value).value(:integer) }
    end

    assert_equal 42, contract.new.call('value' => '+42').to_h.fetch(:value)
    assert_equal 1_000, contract.new.call('value' => '1_000').to_h.fetch(:value)
    assert_equal 9_223_372_036_854_775_808, contract.new.call('value' => '9223372036854775808').to_h.fetch(:value)
  end

  def test_schema_does_not_coerce_keys_or_values
    contract = build_contract do
      schema { required(:age).value(:integer) }
    end

    assert_equal({ age: ['is missing'] }, contract.new.call('age' => '21').errors.to_h)
    assert_equal({ age: ['must be an integer'] }, contract.new.call(age: '21').errors.to_h)
  end

  def test_json_coerces_keys_but_not_values
    contract = build_contract do
      json { required(:age).value(:integer) }
    end

    result = contract.new.call('age' => '21')
    assert_equal({ age: '21' }, result.to_h)
    assert_equal({ age: ['must be an integer'] }, result.errors.to_h)
  end

  def test_key_handling_differs_by_schema_mode_and_filters_undeclared_keys
    declaration = proc do
      required(:profile).hash { required(:name).value(:string) }
      required(:age).value(:integer)
    end

    params = build_contract { params(&declaration) }
    json = build_contract { json(&declaration) }
    schema = build_contract { schema(&declaration) }

    mixed_keys = { 'profile' => { name: 'Jane', 'ignored' => 'value' }, age: 21, 'ignored' => true }

    assert_equal({ profile: { name: 'Jane' }, age: 21 }, params.new.call(mixed_keys).to_h)
    assert_equal({ profile: { name: 'Jane' }, age: 21 }, json.new.call(mixed_keys).to_h)

    schema_result = schema.new.call(mixed_keys)
    assert_equal({ age: 21 }, schema_result.to_h)
    assert_equal({ profile: ['is missing'] }, schema_result.errors.to_h)
  end

  def test_validate_keys_rejects_unknown_keys_in_params_and_json_at_every_hash_level
    declaration = proc do
      required(:profile).hash { required(:name).value(:string) }
      required(:people).array(:hash) { required(:id).value(:integer) }
    end
    params = build_contract do
      config.validate_keys = true
      params(&declaration)
    end
    json = build_contract do
      config.validate_keys = true
      json(&declaration)
    end
    input = {
      'unexpected' => true,
      profile: { name: 'Jane', 'unexpected' => true },
      'people' => [{ id: 1, 'unexpected' => true }]
    }
    expected_errors = {
      unexpected: ['is not allowed'],
      profile: { unexpected: ['is not allowed'] },
      people: { 0 => { unexpected: ['is not allowed'] } }
    }

    [params, json].each do |contract|
      result = contract.new.call(input)

      assert_equal expected_errors, result.errors.to_h
      assert_equal({ profile: { name: 'Jane' }, people: [{ id: 1 }] }, result.to_h)
      assert_equal %i[unexpected_key unexpected_key unexpected_key], result.errors.map(&:code)
    end
  end

  def test_validate_keys_does_not_make_schema_mode_strict
    contract = build_contract do
      config.validate_keys = true
      schema { required(:name).value(:string) }
    end

    result = contract.new.call(name: 'Jane', unexpected: true)

    assert result.success?
    assert_equal({ name: 'Jane' }, result.to_h)
  end

  def test_schema_mode_requires_symbol_keys_at_each_nested_level
    contract = build_contract do
      schema do
        required(:profile).hash { required(:name).value(:string) }
      end
    end

    result = contract.new.call(profile: { 'name' => 'Jane' })

    assert_equal({ profile: {} }, result.to_h)
    assert_equal({ profile: { name: ['is missing'] } }, result.errors.to_h)
  end

  def test_duplicate_key_declarations_fail_explicitly
    error = assert_raises(ArgumentError) do
      build_contract do
        params do
          required(:name).value(:string)
          required(:name).value(:integer)
        end
      end
    end

    assert_equal 'key :name is already defined', error.message
  end

  def test_required_optional_filled_and_maybe
    contract = build_contract do
      params do
        required(:name).filled(:string)
        required(:note).maybe(:string)
        optional(:count).value(:integer)
      end
    end

    result = contract.new.call(name: '', note: nil)
    assert_equal({ name: ['must be filled'] }, result.errors.to_h)
    assert_equal({ name: '', note: nil }, result.to_h)
  end

  def test_schema_presence_semantics_for_symbol_keys_and_empty_containers
    contract = build_contract do
      schema do
        required(:value).value(:string)
        required(:filled).filled(:string)
        required(:maybe).maybe(:string)
        optional(:tags).filled(:array)
        optional(:metadata).filled(:hash)
      end
    end

    result = contract.new.call(value: nil, filled: nil, maybe: nil, tags: [], metadata: {})

    assert_equal(
      { value: ['must be a string'], filled: ['must be a string'], tags: ['must be filled'],
        metadata: ['must be filled'] },
      result.errors.to_h
    )
    assert_equal({ value: nil, filled: nil, maybe: nil, tags: [], metadata: {} }, result.to_h)
  end

  def test_nested_hashes_and_arrays_are_coerced
    contract = build_contract do
      params do
        required(:profile).hash do
          required(:name).filled(:string)
          required(:age).value(:integer)
        end
        required(:scores).array(:integer)
        required(:people).array(:hash) do
          required(:id).value(:integer)
          required(:email).filled(:string)
        end
      end
    end

    result = contract.new.call(
      'profile' => { 'name' => 'Jane', 'age' => '20' },
      'scores' => %w[1 2],
      'people' => [{ 'id' => '7', 'email' => 'jane@example.org' }]
    )

    assert result.success?
    assert_equal 20, result[:profile][:age]
    assert_equal [1, 2], result[:scores]
    assert_equal 7, result[:people][0][:id]
  end

  def test_nested_errors_include_array_indexes
    contract = build_contract do
      params do
        required(:people).array(:hash) do
          required(:age).filled(:integer)
        end
      end
    end

    result = contract.new.call(people: [{ age: 'bad' }, {}])
    assert_equal(
      { people: { 0 => { age: ['must be an integer'] }, 1 => { age: ['is missing'] } } },
      result.errors.to_h
    )
  end

  def test_arrays_preserve_member_output_and_report_each_invalid_member_at_its_index
    contract = build_contract do
      params do
        required(:scores).array(:integer)
        required(:people).array(:hash) do
          required(:id).value(:integer)
          required(:profile).hash { required(:age).value(:integer) }
        end
      end
    end

    result = contract.new.call(
      scores: ['bad', '2', 'also bad'],
      people: [
        { id: 'bad', profile: { age: 'bad' } },
        'not a hash',
        { profile: {} }
      ]
    )

    assert_equal(
      {
        scores: { 0 => ['must be an integer'], 2 => ['must be an integer'] },
        people: {
          0 => { id: ['must be an integer'], profile: { age: ['must be an integer'] } },
          1 => ['must be a hash'],
          2 => { id: ['is missing'], profile: { age: ['is missing'] } }
        }
      },
      result.errors.to_h
    )
    assert_equal(
      { scores: ['bad', 2, 'also bad'],
        people: [{ id: 'bad', profile: { age: 'bad' } }, 'not a hash', { profile: {} }] },
      result.to_h
    )
  end

  def test_arrays_reject_invalid_containers_and_accept_empty_arrays
    contract = build_contract do
      params do
        required(:scores).array(:integer)
        required(:people).array(:hash) { required(:id).value(:integer) }
      end
    end

    invalid = contract.new.call(scores: 'not an array', people: {})
    empty = contract.new.call(scores: [], people: [])

    assert_equal({ scores: ['must be an array'], people: ['must be an array'] }, invalid.errors.to_h)
    assert_equal({ scores: 'not an array', people: {} }, invalid.to_h)
    assert empty.success?
    assert_equal({ scores: [], people: [] }, empty.to_h)
  end

  def test_nested_hashes_validate_multilevel_optional_fields_and_filter_keys
    contract = build_contract do
      params do
        required(:account).hash do
          required(:profile).hash do
            required(:age).value(:integer)
            optional(:nickname).maybe(:string)
          end
          optional(:settings).hash do
            optional(:timezone).value(:string)
          end
        end
      end
    end

    result = contract.new.call(
      'account' => {
        'profile' => { 'age' => 'bad', 'ignored' => true },
        'settings' => { 'timezone' => 'UTC', 'ignored' => true },
        'ignored' => true
      }
    )

    assert_equal({ account: { profile: { age: ['must be an integer'] } } }, result.errors.to_h)
    assert_equal({ account: { profile: { age: 'bad' }, settings: { timezone: 'UTC' } } }, result.to_h)
  end

  def test_nested_hashes_report_missing_and_invalid_parent_containers
    contract = build_contract do
      params do
        required(:account).hash do
          required(:profile).hash { required(:age).value(:integer) }
        end
      end
    end

    missing_parent = contract.new.call('account' => {})
    invalid_parent = contract.new.call('account' => { 'profile' => 'not a hash' })

    assert_equal({ account: { profile: ['is missing'] } }, missing_parent.errors.to_h)
    assert_equal({ account: { profile: ['must be a hash'] } }, invalid_parent.errors.to_h)
    assert_equal({ account: { profile: 'not a hash' } }, invalid_parent.to_h)
  end

  def test_nested_hashes_accept_frozen_input_without_mutating_it
    contract = build_contract do
      params do
        required(:account).hash do
          required(:profile).hash { required(:age).value(:integer) }
        end
      end
    end
    profile = { 'age' => '42', 'ignored' => true }.freeze
    account = { 'profile' => profile, 'ignored' => true }.freeze
    input = { 'account' => account, 'ignored' => true }.freeze

    result = contract.new.call(input)

    assert result.success?
    assert_equal({ account: { profile: { age: 42 } } }, result.to_h)
    assert_equal(
      { 'account' => { 'profile' => { 'age' => '42', 'ignored' => true }, 'ignored' => true },
        'ignored' => true }, input
    )
    assert input.frozen?
    assert account.frozen?
    assert profile.frozen?
  end

  def test_native_and_ruby_predicates
    contract = build_contract do
      params do
        required(:age).value(:integer, gteq?: 18)
        required(:name).filled(:string, min_size?: 3)
        required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/)
        required(:role).value(:string, included_in?: %w[admin user])
      end
    end

    result = contract.new.call(age: '17', name: 'Al', email: 'bad', role: 'root')
    assert_equal 4, result.errors.count
    assert_equal 'must be greater than or equal to 18', result.errors.to_h[:age].first
  end

  def test_predicate_composition_blocks_collect_native_and_ruby_predicates
    contract = build_contract do
      params do
        required(:age).value(:integer) { gt? 18 }
        required(:email).value(:string) { format?(/\A[^@]+@[^@]+\z/) }
      end
    end

    invalid = contract.new.call(age: '18', email: 'invalid')
    valid = contract.new.call(age: '19', email: 'jane@example.test')

    assert_equal({ age: ['must be greater than 18'], email: ['is in invalid format'] }, invalid.errors.to_h)
    assert_equal %i[gt? format?], invalid.errors.map(&:predicate)
    assert valid.success?
  end

  def test_predicate_composition_blocks_reject_invalid_predicate_arities
    multiple_arguments = assert_raises(ArgumentError) do
      build_contract do
        params { required(:age).value(:integer) { gt?(18, 19) } }
      end
    end
    missing_argument = assert_raises(ArgumentError) do
      build_contract do
        params { required(:age).value(:integer) { gt? } }
      end
    end
    unexpected_argument = assert_raises(ArgumentError) do
      build_contract do
        params { required(:age).value(:integer) { odd? 1 } }
      end
    end

    assert_equal 'gt? expects exactly one argument, got 2', multiple_arguments.message
    assert_equal 'gt? expects exactly one argument, got 0', missing_argument.message
    assert_equal 'odd? expects no arguments, got 1', unexpected_argument.message
  end

  def test_custom_dry_types_are_processed_in_ruby_alongside_native_fields
    email_type = Dry::Types['params.string'].constructor { |value| value.strip.downcase }
    identifier_type = Dry::Types['params.integer'] | Dry::Types['params.string']
    contract = build_contract do
      params do
        required(:age).value(:integer)
        required(:email).value(email_type)
        required(:identifier).value(identifier_type)
      end
    end

    valid = contract.new.call(age: '42', email: ' JANE@EXAMPLE.TEST ', identifier: 'abc')
    invalid = contract.new.call(age: 'bad', email: ' JANE@EXAMPLE.TEST ', identifier: [])

    assert_equal({ age: 42, email: 'jane@example.test', identifier: 'abc' }, valid.to_h)
    assert valid.success?
    assert_equal({ age: 'bad', email: 'jane@example.test', identifier: [] }, invalid.to_h)
    assert_equal({ age: ['must be an integer'], identifier: ['is invalid'] }, invalid.errors.to_h)
  end

  def test_custom_dry_types_array_members_fail_explicitly
    type = Dry::Types['params.integer']

    error = assert_raises(Dry::Validation::Rust::UnsupportedFeatureError) do
      build_contract { params { required(:ids).array(type) } }
    end

    assert_equal 'custom dry-types array members are not supported by the Ruby fallback yet', error.message
  end

  def test_predicate_composition_blocks_reject_non_predicate_expressions_explicitly
    error = assert_raises(Dry::Validation::Rust::UnsupportedFeatureError) do
      build_contract do
        params { required(:age).value(:integer) { required(:child) } }
      end
    end

    assert_equal 'unsupported predicate composition expression: :required', error.message
  end

  def test_value_hash_blocks_continue_to_define_nested_fields
    contract = build_contract do
      params do
        required(:profile).value(:hash) do
          required(:name).value(:string)
        end
      end
    end

    valid = contract.new.call(profile: { name: 'Jane' })
    invalid = contract.new.call(profile: {})

    assert_equal({ profile: { name: 'Jane' } }, valid.to_h)
    assert valid.success?
    assert_equal({ profile: { name: ['is missing'] } }, invalid.errors.to_h)
  end

  def test_ruby_predicates_are_skipped_for_paths_with_native_errors
    contract = build_contract do
      params do
        required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/)
      end
    end

    result = contract.new.call(email: 42)

    assert_equal({ email: ['must be a string'] }, result.errors.to_h)
  end

  def test_predicate_errors_preserve_paths_codes_and_arguments
    contract = build_contract do
      params do
        required(:age).value(:integer, gt?: 18)
        required(:profile).hash do
          required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/)
        end
        required(:role).value(:string, included_in?: %w[admin user])
      end
    end

    errors = contract.new.call(
      age: '18', profile: { email: 'invalid' }, role: 'guest'
    ).errors

    assert_equal [[:age], %i[profile email], [:role]], errors.map(&:path)
    assert_equal %i[gt format included_in], errors.map(&:code)
    assert_equal %i[gt? format? included_in?], errors.map(&:predicate)
    assert_equal [[18], [/\A[^@]+@[^@]+\z/], [%w[admin user]]], errors.map(&:args)
    assert_equal [{}, {}, {}], errors.map(&:meta)
  end

  def test_native_predicate_errors_resolve_fields_through_nested_hashes_and_array_members
    contract = build_contract do
      params do
        required(:account).hash do
          required(:profile).hash do
            required(:age).value(:integer, gt?: 18)
          end
        end
        required(:people).array(:hash) do
          required(:score).value(:integer, lt?: 10)
        end
      end
    end

    errors = contract.new.call(account: { profile: { age: '18' } }, people: [{ score: '10' }]).errors

    assert_equal %i[gt? lt?], errors.map(&:predicate)
    assert_equal [[18], [10]], errors.map(&:args)
  end

  def test_predicates_accept_valid_values_and_skip_wrong_types
    contract = build_contract do
      params do
        required(:age).value(:integer, gt?: 18)
        required(:email).value(:string, format?: /\A[^@]+@[^@]+\z/)
      end
    end

    assert contract.new.call(age: '19', email: 'jane@example.test').success?

    error = contract.new.call(age: 'not-a-number', email: 42).errors.first
    assert_equal 'must be an integer', error.text
    assert_equal :type, error.code
    assert_nil error.predicate
    assert_equal [], error.args
    assert_equal({}, error.meta)
  end

  def test_unknown_predicates_fail_when_the_schema_is_declared
    error = assert_raises(Dry::Validation::Rust::UnsupportedFeatureError) do
      build_contract do
        params { required(:age).value(:integer, unknown?: 1) }
      end
    end

    assert_equal 'predicate :unknown is not supported natively; move it to a contract rule', error.message
  end

  def test_filled_failure_skips_native_predicates
    contract = build_contract do
      params { required(:name).filled(:string, min_size?: 3) }
    end

    assert_equal({ name: ['must be filled'] }, contract.new.call(name: '').errors.to_h)
    assert_equal({ name: ['size cannot be less than 3'] }, contract.new.call(name: 'Al').errors.to_h)
  end

  def test_dates_times_and_decimals
    contract = build_contract do
      params do
        required(:date).value(:date)
        required(:at).value(:time)
        required(:amount).value(:decimal)
      end
    end

    result = contract.new.call(date: '2026-07-12', at: '2026-07-12T10:00:00Z', amount: '12.50')
    assert result.success?
    assert_instance_of Date, result[:date]
    assert_instance_of Time, result[:at]
    assert_instance_of BigDecimal, result[:amount]
  end

  def test_invalid_temporal_and_decimal_values_become_validation_errors
    contract = build_contract do
      params do
        required(:date).value(:date)
        required(:at).value(:time)
        required(:amount).value(:decimal)
      end
    end

    result = contract.new.call(date: 'not-a-date', at: 'not-a-time', amount: 'not-a-number')
    assert_equal(
      {
        date: ['must be a date'],
        at: ['must be a time'],
        amount: ['must be a decimal']
      },
      result.errors.to_h
    )
  end

  def test_input_must_be_a_hash
    contract = build_contract { params { required(:name).filled(:string) } }
    error = assert_raises(ArgumentError) { contract.new.call([]) }
    assert_match(/Input must be a Hash/, error.message)
  end

  private

  def nested_schema(nesting_depth, level = 0)
    return proc { required(:"level_#{level}").value(:integer) } if level == nesting_depth

    child_schema = nested_schema(nesting_depth, level + 1)
    proc { required(:"level_#{level}").hash(&child_schema) }
  end

  def with_message_file(contents)
    Tempfile.create(['dry-validation-rust-messages', '.yml']) do |file|
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  def nested_input(nesting_depth)
    nested_output(nesting_depth, '42', key_type: :string)
  end

  def nested_output(nesting_depth, value = 42, key_type: :symbol)
    nesting_depth.downto(0).reduce(value) do |nested, level|
      key = key_type == :symbol ? :"level_#{level}" : "level_#{level}"
      { key => nested }
    end
  end
end
