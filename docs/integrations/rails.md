# Rails

`dry-validation-rust` is used at the controller boundary. It does not provide a
Rails model validator or a controller concern: keep the contract in
`app/contracts` and pass it the permitted request attributes.

## Load the API

Add the gem to the application's `Gemfile`, then load the side-by-side API at
boot so a missing native extension fails early:

```ruby
# config/initializers/dry_validation_rust.rb
require "dry/validation/rust"
```

Define an application-owned contract:

```ruby
# app/contracts/users/create_contract.rb
class Users::CreateContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
  end

  rule(:age) do
    key.failure("must be at least 18") if value < 18
  end
end
```

## Validate strong parameters

Permit only fields that the endpoint accepts, convert the resulting
`ActionController::Parameters` to a hash, and validate that hash:

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def create
    result = Users::CreateContract.new.call(user_params.to_h)

    if result.success?
      user = User.create!(result.to_h)
      render json: user, status: :created
    else
      render json: { errors: result.errors.to_h }, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :age)
  end
end
```

Strong parameters define the controller's accepted input; the contract checks
shape, coercion, and domain rules. Do not rely on either one as a substitute
for the other.

## Use Rails I18n translations for schema errors

Rails already includes `i18n`. Configure the contract before its `params`
block, and point its message backend at an application locale file:

```ruby
class Users::CreateContract < Dry::Validation::Rust::Contract
  config.messages.backend = :i18n
  config.messages.default_locale = :en
  config.messages.load_paths << Rails.root.join("config/locales/validation.en.yml")

  params { required(:email).filled(:string) }
end
```

```yaml
# config/locales/validation.en.yml
en:
  dry_validation:
    errors:
      filled?: "must be provided"
```

The selected locale is compiled into the schema. Use a contract configured for
the needed locale, rather than expecting a per-request `I18n.locale` change to
alter an already compiled contract. Rule failures supplied as strings remain
application-owned text.

See [Getting started](../getting-started.md) for supported DSL details and
[Compatibility](../COMPATIBILITY.md) for boundaries.
