# Roda

Instantiate a contract in the route that owns the input boundary. Roda needs
no plugin or middleware for this integration.

```ruby
# app/contracts/users/create_contract.rb
class Users::CreateContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
  end
end
```

For a JSON endpoint, parse the request body and return structured validation
errors when the contract fails:

```ruby
require "json"
require "roda"
require "dry/validation/rust"

class App < Roda
  route do |r|
    r.post "users" do
      result = Users::CreateContract.new.call(JSON.parse(r.body.read))

      response["Content-Type"] = "application/json"
      if result.success?
        response.status = 201
        JSON.generate(result.to_h)
      else
        response.status = 422
        JSON.generate(errors: result.errors.to_h)
      end
    end
  end
end
```

`JSON.parse` produces string keys, which `params` schemas accept. Keep parsing
errors separate from validation failures if the endpoint must distinguish an
invalid JSON document from valid JSON with invalid fields.

See [Getting started](../getting-started.md) for the contract API and
[Compatibility](../COMPATIBILITY.md) for the supported DSL subset.
