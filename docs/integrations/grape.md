# Grape

Grape's `params` block documents and filters endpoint parameters. Pass the
declared values to a contract for coercion and application validation; this
keeps Grape's routing concerns separate from reusable validation logic.

```ruby
# app/contracts/users/create_contract.rb
class Users::CreateContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
  end
end
```

```ruby
require "grape"
require "dry/validation/rust"

class UsersAPI < Grape::API
  format :json

  resource :users do
    params do
      requires :email, type: String
      requires :age, type: Integer
    end
    post do
      result = Users::CreateContract.new.call(declared(params, include_missing: false))

      error!({ errors: result.errors.to_h }, 422) unless result.success?

      status 201
      result.to_h
    end
  end
end
```

Grape may reject values before the contract runs when its `type` declarations
cannot coerce them. Use the contract error payload as the endpoint's
application-validation response; preserve Grape's own parameter errors for
request-shape failures.

See [Getting started](../getting-started.md) for the contract API and
[Compatibility](../COMPATIBILITY.md) for the supported DSL subset.
