# frozen_string_literal: true

require_relative 'test_helper'

class SchemaTest < Minitest::Test
  def test_native_engine_uses_schema_error_buffer_version
    schema = Dry::Validation::Rust::Schema.Params { required(:age).value(:integer) }

    _output, native_errors = schema.engine.call(age: 'invalid')

    assert_equal Dry::Validation::Rust::Schema::NATIVE_ERROR_BUFFER_VERSION, native_errors.first
  end

  def test_native_error_buffer_rejects_unsupported_versions_and_truncated_records
    schema = Dry::Validation::Rust::Schema.Params { required(:age).value(:integer) }
    format_version = Dry::Validation::Rust::Schema::NATIVE_ERROR_BUFFER_VERSION

    version_error = assert_raises(Dry::Validation::Rust::NativeExtensionError) do
      schema.send(:native_errors_to_messages, [format_version + 1])
    end
    assert_equal "unsupported native error buffer version: #{format_version + 1}", version_error.message

    malformed_error = assert_raises(Dry::Validation::Rust::NativeExtensionError) do
      schema.send(:native_errors_to_messages, [format_version, 1, :age])
    end
    assert_equal 'malformed native error buffer', malformed_error.message

    invalid_value_error = assert_raises(Dry::Validation::Rust::NativeExtensionError) do
      schema.send(:native_errors_to_messages, [format_version, 1, 'age', :type, 'must be an integer'])
    end
    assert_equal 'malformed native error buffer', invalid_value_error.message
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
end
