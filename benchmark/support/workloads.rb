# frozen_string_literal: true

module DryValidationRustBenchmark
  Workload = Data.define(:name, :description, :contract_builder, :valid_inputs, :invalid_inputs) do
    def build_contract(base_class)
      contract_builder.call(base_class).new
    end

    def inputs_for(distribution)
      case distribution
      when "valid" then valid_inputs
      when "invalid" then invalid_inputs
      when "mixed" then [valid_inputs.first, invalid_inputs.first]
      else raise ArgumentError, "unknown distribution: #{distribution.inspect}"
      end
    end
  end

  module Workloads
    module_function

    def all
      @all ||= [shallow, nested, array_of_hashes].to_h { |workload| [workload.name, workload] }.freeze
    end

    def fetch(name)
      all.fetch(name) { raise ArgumentError, "unknown workload: #{name.inspect}" }
    end

    def shallow
      Workload.new(
        name: "shallow",
        description: "Two-field Params schema exposing fixed native-boundary overhead",
        contract_builder: lambda do |base_class|
          Class.new(base_class) do
            params do
              required(:id).value(:integer, gt?: 0)
              optional(:active).value(:bool)
            end
          end
        end,
        valid_inputs: [{"id" => "42", "active" => "true"}].freeze,
        invalid_inputs: [{"id" => "not-an-integer", "active" => "maybe"}].freeze
      )
    end

    def nested
      Workload.new(
        name: "nested",
        description: "Nested Params payload with coercions, arrays, predicates, and a Ruby rule",
        contract_builder: lambda do |base_class|
          Class.new(base_class) do
            params do
              required(:id).value(:integer, gt?: 0)
              required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
              required(:active).value(:bool)
              required(:tags).array(:string)
              required(:profile).hash do
                required(:name).filled(:string)
                required(:age).value(:integer, gteq?: 0)
              end
            end

            rule("profile.age") do
              key.failure("must be at least 18") if value < 18
            end
          end
        end,
        valid_inputs: [
          {
            "id" => "42",
            "email" => "jane@example.org",
            "active" => "true",
            "tags" => %w[ruby rust validation],
            "profile" => {"name" => "Jane", "age" => "31"}
          }
        ].freeze,
        invalid_inputs: [
          {
            "id" => "-1",
            "email" => "invalid",
            "active" => "unknown",
            "tags" => ["ruby", 7],
            "profile" => {"name" => "", "age" => "16"}
          }
        ].freeze
      )
    end

    def array_of_hashes
      valid_items = Array.new(24) do |index|
        {
          "sku" => "SKU-#{index + 1}",
          "quantity" => ((index % 4) + 1).to_s,
          "price" => format("%.2f", 1.25 + index),
          "tags" => ["bulk", "item-#{index + 1}"]
        }
      end
      invalid_items = valid_items.map(&:dup)
      invalid_items[5] = invalid_items.fetch(5).merge("quantity" => "0")
      invalid_items[17] = invalid_items.fetch(17).merge("sku" => "", "price" => "free")

      Workload.new(
        name: "array_of_hashes",
        description: "Bounded 24-element array of nested hashes with repeated coercion and traversal",
        contract_builder: lambda do |base_class|
          Class.new(base_class) do
            params do
              required(:items).array(:hash) do
                required(:sku).filled(:string)
                required(:quantity).value(:integer, gt?: 0)
                required(:price).value(:float, gt?: 0.0)
                optional(:tags).array(:string)
              end
            end
          end
        end,
        valid_inputs: [{"items" => valid_items}.freeze].freeze,
        invalid_inputs: [{"items" => invalid_items}.freeze].freeze
      )
    end
  end
end
