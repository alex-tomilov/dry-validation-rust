# frozen_string_literal: true

require "dry/validation/rust"

# A compact judge-facing example.
#
# Rust owns the supported schema plan, coercion, traversal, predicates,
# normalized output, and structural errors. Ruby owns the business rule and
# the optional observer used to prove dependency-based rule skipping.
class BuildWeekOrderContract < Dry::Validation::Rust::Contract
  option :observer, optional: true

  params do
    required(:customer).hash do
      required(:email).filled(:string, format?: /\A[^@\s]+@[^@\s]+\z/)
      required(:age).value(:integer)
    end

    required(:items).array(:hash) do
      required(:sku).filled(:string)
      required(:quantity).value(:integer, gt?: 0)
    end
  end

  rule("customer.age") do
    observer&.call
    key.failure("must be at least 18") if value < 18
  end
end

module BuildWeekDemo
  module_function

  def valid_input
    {
      "customer" => {
        "email" => "jane@example.org",
        "age" => "32",
        "ignored" => "filtered"
      },
      "items" => [
        {"sku" => "BOOK-1", "quantity" => "2", "ignored" => "filtered"},
        {"sku" => "MUG-2", "quantity" => "1"}
      ],
      "ignored" => "filtered"
    }
  end

  def invalid_input
    {
      "customer" => {
        "email" => "not-an-email",
        "age" => "16"
      },
      "items" => [
        {"sku" => "BOOK-1", "quantity" => "0"}
      ]
    }
  end

  def failed_coercion_input
    {
      "customer" => {
        "email" => "jane@example.org",
        "age" => "not-an-integer"
      },
      "items" => [
        {"sku" => "BOOK-1", "quantity" => "1"}
      ]
    }
  end
end
