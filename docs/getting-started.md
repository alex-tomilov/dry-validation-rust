# Getting started

This guide takes you from installing `dry-validation-rust` to validating a
request in about 15 minutes. It uses the supported side-by-side API, which can
coexist with upstream `dry-validation` and `dry-schema`.

Before using the gem in an application, review the supported Ruby versions and
platforms in [SUPPORT_MATRIX.md](SUPPORT_MATRIX.md), and the supported DSL
subset in [COMPATIBILITY.md](COMPATIBILITY.md).

## Install

Install a precompiled gem when one is available for your platform:

```bash
gem install dry-validation-rust
```

### Build from source

If your platform does not have a precompiled gem, RubyGems builds from source.
Source builds require:

- CRuby 3.3 or newer with development headers;
- Rust 1.75 or newer and Cargo;
- a C toolchain; and
- libclang for the `rb-sys` bindgen step.

On Linux, install the distribution's `clang` and `libclang-dev` packages. On
macOS, install Xcode Command Line Tools and LLVM, then point bindgen to
Homebrew's keg-only library:

```bash
brew install llvm
export LIBCLANG_PATH="$(brew --prefix llvm)/lib"
```

On Windows with RubyInstaller, use its DevKit UCRT Clang package rather than
the standalone LLVM distribution; bindgen must use the same headers and C
runtime as Ruby:

```powershell
ridk exec pacman -S --needed mingw-w64-ucrt-x86_64-clang
$env:LIBCLANG_PATH = "$env:RI_DEVKIT\ucrt64\bin"
```

The extension automatically selects Rust's matching GNU toolchain when it is
built by a MinGW Ruby. Confirm that `cargo` and your C compiler are on `PATH`,
and that `LIBCLANG_PATH` contains the `libclang` library, before retrying a
failed install. A source checkout pins Rust 1.75.0 through
`rust-toolchain.toml`.

```bash
gem install dry-validation-rust --platform ruby
```

For an application managed by Bundler, add this to its `Gemfile` and run
`bundle install`:

```ruby
gem "dry-validation-rust"
```

## Write your first contract

Create `validate_user.rb`:

```ruby
require "dry/validation/rust"

class UserContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
  end

  rule(:age) do
    key.failure("must be at least 18") if value < 18
  end
end

result = UserContract.new.call(email: "ada@example.test", age: "17")

if result.success?
  puts result.to_h
else
  puts result.errors.to_h
end
# {:age=>["must be at least 18"]}
```

Run it with:

```bash
ruby validate_user.rb
```

`params` normalizes string keys and coerces supported input types, so the
string `"17"` becomes an integer before the rule runs. A schema failure (for
example, a missing email) prevents dependent rules from running. Use
`result.success?` to choose the happy path and `result.errors.to_h` to return
or display structured errors.

## Add a custom rule or macro

Rules hold application-specific checks. Use `key.failure` to attach a message
to the rule's field:

```ruby
rule(:email) do
  key.failure("uses a blocked domain") if value.end_with?("@example.invalid")
end
```

When the same check is useful to several fields, register a macro and invoke
it with `rule(...).validate`:

```ruby
class ProfileContract < Dry::Validation::Rust::Contract
  register_macro(:minimum) do |macro:|
    key.failure("must be at least #{macro.args.fetch(0)}") if value < macro.args.fetch(0)
  end

  params do
    required(:age).value(:integer)
  end

  rule(:age).validate(minimum: 18)
end
```

Macros can be registered globally with
`Dry::Validation::Rust.register_macro`, or on an individual contract as above.
See [COMPATIBILITY.md](COMPATIBILITY.md#options-and-macros) for their supported
surface.

## Use it in a web app

Keep the contract in an application-owned class (for example,
`app/contracts/user_contract.rb`) and instantiate it at the request boundary.

### Rails controller

```ruby
class UsersController < ApplicationController
  def create
    result = UserContract.new.call(user_params.to_h)

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

### Sinatra app

```ruby
require "sinatra"
require "json"
require "dry/validation/rust"

post "/users" do
  result = UserContract.new.call(JSON.parse(request.body.read))

  content_type :json
  if result.success?
    status 201
    JSON.generate(result.to_h)
  else
    status 422
    JSON.generate(errors: result.errors.to_h)
  end
end
```

The Sinatra example accepts JSON input. `params` accepts either string or
symbol keys, so no key conversion is needed after `JSON.parse`.

### Framework guides

The gem has no framework adapters: call an application-owned contract at the
request boundary and return `result.to_h` or `result.errors.to_h`. Minimal
examples for common frameworks are available for [Rails](integrations/rails.md),
[Hanami](integrations/hanami.md), [Roda](integrations/roda.md), and
[Grape](integrations/grape.md).

## Choose a loading mode

For new applications, load the side-by-side API:

```ruby
require "dry/validation/rust"

class SignupContract < Dry::Validation::Rust::Contract
  # ...
end
```

This is the supported mode and does not take over upstream `Dry::Validation`
or `Dry::Schema` constants.

The upstream-like `require "dry/validation"` and `require "dry/schema"`
entrypoints are deprecated exact compatibility mode. They cannot safely share a
process with upstream `dry-validation` or `dry-schema`, because they use the
same require paths and constants. Do not start new work in exact mode; existing
users should follow [MIGRATION_FROM_EXACT_MODE.md](MIGRATION_FROM_EXACT_MODE.md).

## Troubleshooting

### `native extension not found`

From a source checkout, compile the extension before running the example:

```bash
bundle exec rake compile
```

Then rerun through Bundler (`bundle exec ruby validate_user.rb`) so Ruby loads
the checkout's compiled extension. For an installed gem, reinstall it after
resolving the build error so RubyGems can build the extension.

### `libclang` missing or bindgen cannot find it

Install LLVM and make its libclang library discoverable. On Linux, install the
distribution's `clang` and `libclang-dev` packages. On macOS:

```bash
brew install llvm
export LIBCLANG_PATH="$(brew --prefix llvm)/lib"
```

On Windows with RubyInstaller, use the DevKit UCRT Clang package; see
[WINDOWS.md](WINDOWS.md). Retry the install after setting `LIBCLANG_PATH`.

### Rust is too old

Install or upgrade Rust and Cargo to Rust 1.75 or newer, then retry the source
build:

```bash
rustup update stable
rustc --version
```

The source checkout pins the project's supported toolchain automatically. See
[Build from source](#build-from-source) for the complete source-build
requirements.
