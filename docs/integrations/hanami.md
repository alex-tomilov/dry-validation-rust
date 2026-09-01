# Hanami

Use a contract from a Hanami action after reading the action's request
parameters. The contract stays independent of Hanami, which makes it usable
from another action or a background job.

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
# app/actions/users/create.rb
module Web
  module Actions
    module Users
      class Create < Hanami::Action
        def handle(request, response)
          result = ::Users::CreateContract.new.call(request.params.to_h)

          if result.success?
            response.status = 201
            response.body = result.to_h.to_json
          else
            response.status = 422
            response.body = { errors: result.errors.to_h }.to_json
          end
        end
      end
    end
  end
end
```

Set the response content type using the application's usual Hanami route or
action configuration. `params` accepts both string and symbol keys and
performs supported coercions before rules run.

See [Getting started](../getting-started.md) for the contract API and
[Compatibility](../COMPATIBILITY.md) for the supported DSL subset.
