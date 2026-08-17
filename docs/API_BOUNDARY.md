# Message backend adapter

Schemas resolve translated error text through a message-backend adapter. The
built-in adapters are selected with `:yaml` (the default) and `:i18n`:

```ruby
config.messages.backend = :yaml
config.messages.backend = :i18n
```

To use another source, assign a subclass of
`Dry::Validation::Rust::MessageBackend`. The constructor receives the current
`MessageConfig`; implement `#message` to return the resolved text. The keyword
arguments provide the error code, predicate, predicate arguments, normalized
field type, and native fallback text.

```ruby
class CustomBackend < Dry::Validation::Rust::MessageBackend
  def message(code:, fallback:, **)
    "CUSTOM: #{code}"
  end
end

config.messages.backend = CustomBackend
```

An adapter must return a string. Unsupported identifiers or classes that do
not inherit from `MessageBackend` raise `ArgumentError` when assigned.
