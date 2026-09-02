# Migration recipes for unsupported schema DSL features

This guide covers the intentionally unsupported schema DSL constructs in the
current compatibility slice. Each raises `UnsupportedFeatureError` at schema
declaration time rather than being silently ignored.

## Boolean predicate composition

Predicate blocks accept sequential supported predicates, but not dry-logic AST
operators such as `&`, `|`, or `>`.

Instead of a boolean predicate expression, declare sequential rules when all
conditions must hold:

```ruby
# Unsupported: gt?(18) & lt?(65)
required(:age).value(:integer) { gt? 18; lt? 65 }
```

For conditional or alternative validation, use a contract rule and add the
failure explicitly.

## UUID and other dry-logic predicates

The dry-logic `uuid?` predicate is not part of the supported predicate set.
Use the supported `format?` predicate with an application-appropriate regular
expression instead:

```ruby
UUID_PATTERN = /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i

required(:id).value(:string) { format? UUID_PATTERN }
```

For predicates that cannot be expressed with the supported set, use a contract
rule and call `key.failure` when the value is invalid.

## Schema filtering DSL

The upstream schema filtering DSL is not implemented. Validate and coerce the
payload first, then explicitly select the output your application exposes:

```ruby
result = contract.new.call(input)
public_attributes = result.to_h.slice(:name, :email)
```

This keeps output filtering in application code, where its authorization and
presentation semantics are explicit.
