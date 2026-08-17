# API Boundary

The supported Ruby API is the compatibility surface exposed through
`require "dry-validation"` and `require "dry-schema"`. The equivalent
`Dry::Validation::Rust` constants remain available for direct use.

## Public classes

- `Dry::Validation::Rust::Schema` and `Schema::Result`
- `Dry::Validation::Rust::Contract`, `Contract::Result`, and `Contract::Values`
- `Dry::Validation::Rust::Evaluator` within `Contract.rule` blocks
- `Dry::Validation::Rust::Rule`, `Failures`, `Message`, and `MessageSet`
- `Dry::Validation::Rust::Config` and `MessageConfig`
- The documented error classes under `Dry::Validation::Rust`

The public construction and DSL entry points are `Dry::Schema.Params`,
`Dry::Schema.JSON`, `Dry::Schema.define`, `Dry::Validation.Contract`,
`Dry::Validation.register_macro`, and `Dry::Validation.load_extensions`.

## Private implementation classes

The following constants are implementation details and are marked `@api private`
in YARD. Their names, constructors, and behavior may change without notice:

- `Schema::DSL`, `Schema::FieldBuilder`, `Schema::FieldDefinition`,
  `Schema::Predicate`, `Schema::PredicateBlock`, `Schema::ProcessorHooks`, and
  `Schema::RubyTypeProcessor`
- `Contract::OptionDefinition`, `Macro`, `MacroRegistry`, and
  `BlockKeywordParameters`
- `Path`, `Native`, and `MessageBackend`

Internal lifecycle methods, including schema predicate execution, contract rule
execution, evaluator setup, native-plan access, and macro resolution, are also
marked `@api private` even where Ruby visibility must remain public for internal
collaboration.
