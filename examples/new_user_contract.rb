# frozen_string_literal: true

require 'dry/validation'

class NewUserContract < Dry::Validation::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@\s]+@[^@\s]+\z/)
    required(:age).value(:integer)
    optional(:display_name).maybe(:string)
    required(:addresses).array(:hash) do
      required(:city).filled(:string)
      required(:postcode).filled(:string)
    end
  end

  rule(:age) do
    key.failure('must be at least 18') if value < 18
  end
end

result = NewUserContract.new.call(
  'email' => 'jane@example.org',
  'age' => '17',
  'display_name' => '',
  'addresses' => [{ 'city' => 'Astana', 'postcode' => '010000' }]
)

warn result.inspect
