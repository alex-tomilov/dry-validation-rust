# frozen_string_literal: true

require 'json'
require 'date'
require 'time'
require 'bigdecimal'
require_relative 'generated_predicates'

module Dry
  module Validation
    module Rust
      # A compiled schema that validates and coerces input hashes.
      #
      # @example Define and call a schema
      #   schema = Dry::Validation::Rust::Schema.Params do
      #     required(:age).value(:integer)
      #   end
      #   result = schema.call("age" => "25")
      #   result.to_h # => { age: 25 }
      class Schema
        # Type symbols supported by schema fields.
        #
        # @return [Array<Symbol>]
        TYPES = %i[
          any nil bool true false integer float decimal string symbol array hash
          date date_time datetime time
        ].freeze
        # @api private
        Predicate = Data.define(:name, :argument) do
          def initialize(name:, argument: true)
            super(name: name.to_s.delete_suffix('?').to_sym, argument: argument)
          end
        end
      end

      require_relative 'schema/result'
      require_relative 'schema/processor_hooks'
      require_relative 'schema/field_definition'
      require_relative 'schema/predicate_block'
      require_relative 'schema/field_builder'
      require_relative 'schema/ruby_type_processor'
      require_relative 'schema/dsl'

      class Schema
        # @return [Symbol] the schema input mode.
        attr_reader :mode

        # @api private
        # @return [Array<FieldDefinition>] the compiled top-level field definitions.
        attr_reader :fields

        # @api private
        # @return [Native::Engine] the native engine that executes this schema.
        attr_reader :engine

        # Builds a schema from a DSL block and optional schemas to import.
        #
        # @param mode [Symbol] the input mode, such as `:schema`, `:params`, or `:json`.
        # @param external_schemas [Array<Schema>] compiled schemas whose fields are imported.
        # @yield the schema DSL block.
        # @return [Schema] the compiled schema.
        def self.define(mode = :schema, *external_schemas, &block)
          dsl = DSL.new(mode: mode)
          external_schemas.each { |schema| dsl.import(schema) }
          dsl.instance_eval(&block) if block
          dsl.compile
        end

        # Builds a schema that coerces web request parameter input.
        #
        # @param external_schemas [Array<Schema>] compiled schemas whose fields are imported.
        # @yield the schema DSL block.
        # @return [Schema] the compiled params-mode schema.
        def self.Params(*external_schemas, &) = define(:params, *external_schemas, &)

        # Builds a schema that coerces JSON-compatible input.
        #
        # @param external_schemas [Array<Schema>] compiled schemas whose fields are imported.
        # @yield the schema DSL block.
        # @return [Schema] the compiled JSON-mode schema.
        def self.JSON(*external_schemas, &) = define(:json, *external_schemas, &)

        # Compiles field definitions into a native schema plan.
        #
        # @api private
        #
        # @param mode [Symbol] the input mode.
        # @param fields [Array<FieldDefinition>] field definitions to compile.
        # @param before_hooks [Array<#call>] processors run before native validation.
        # @param after_hooks [Array<#call>] processors run after native validation.
        # @param validate_keys [Boolean] whether unknown keys are validation errors.
        # @param messages [MessageConfig] validation message configuration.
        # @raise [NativeExtensionError] if the native schema plan cannot be compiled.
        def initialize(mode:, fields:, before_hooks: [], after_hooks: [], validate_keys: false,
                       messages: MessageConfig.new)
          @mode = mode.to_sym
          @fields = fields.freeze
          @fields_by_name = fields.to_h { |field| [field.name, field] }.freeze
          @before_hooks, @after_hooks = [before_hooks, after_hooks].map { _1.dup.freeze }
          @message_backend = MessageBackend.new(messages)
          begin
            plan = {
              engine_version: ENGINE_VERSION,
              mode: mode.to_s,
              validate_keys: validate_keys,
              fields: fields.map(&:to_native_h)
            }
            @engine = Native::Engine.new(JSON.generate(plan, max_nesting: false))
          rescue StandardError => e
            raise NativeExtensionError, "could not compile native schema plan: #{e.message}"
          end
        end

        # Validates and coerces a Hash.
        #
        # @param input [Hash] input to validate.
        # @return [Result] the output and validation messages.
        # @raise [ArgumentError] if +input+ is not a Hash.
        def call(input)
          raise ArgumentError, "Input must be a Hash. #{input.class} was given." unless input.is_a?(Hash)

          # Before hooks receive an isolated copy and may safely mutate nested values.
          prepared_input = before_hooks.empty? ? input.dup : ProcessorHooks.deep_dup(input)
          prepared_input = ProcessorHooks.apply(before_hooks, prepared_input)
          result = engine.call(prepared_input)
          output = ProcessorHooks.apply(after_hooks, result.output)
          messages = result.errors.map do |error|
            path = error[:path]
            code = error[:code]
            text = error[:text]
            predicate, args = native_predicate_details(path, code)
            native_message(path, code, text, predicate, args)
          end
          RubyTypeProcessor.apply(fields, output, messages, @message_backend)
          apply_ruby_predicates(fields, output, [], messages)
          Result.new(output, messages.freeze)
        end

        # Validates and coerces a Hash.
        #
        # Alias for {#call}.
        #
        # @param input [Hash] input to validate.
        # @return [Result] the output and validation messages.
        # @raise [ArgumentError] if +input+ is not a Hash.
        def [](input)
          call(input)
        end

        # Returns all declared field paths, including nested array paths.
        #
        # @api private
        #
        # @return [Array<Array<Symbol, Integer>>] declared field paths. Array members
        #   use +:__index__+ as an index placeholder.
        def key_paths
          paths_for(fields)
        end

        # Returns a diagnostic representation of this compiled schema.
        #
        # @return [String] the schema mode, field names, and native-engine marker.
        def inspect
          "#<#{self.class} mode=#{mode.inspect} fields=#{fields.map(&:name).inspect} native=true>"
        end

        private

        attr_reader :before_hooks, :after_hooks

        # @api private
        def native_message(path, code, text, predicate, args)
          Message.new(
            text: native_error_message(code, text, predicate, args, path),
            path: path, code: code, source: :schema, predicate: predicate, args: args
          )
        end

        # @api private
        def native_error_message(code, native_text, predicate, args, path)
          field = field_at_path(path)
          @message_backend.message(
            code: code, predicate: predicate&.to_s&.delete_suffix('?'), args: args,
            type: field&.normalized_type, fallback: native_text
          )
        end

        # @api private
        def paths_for(definitions, prefix = [])
          definitions.flat_map do |field|
            current = [*prefix, field.name]
            nested = paths_for(field.children, current)
            member_nested = field.member ? paths_for(field.member.children, [*current, :__index__]) : []
            [current, *nested, *member_nested]
          end
        end

        # @api private
        def apply_ruby_predicates(definitions, data, prefix, messages)
          error_paths = messages.to_set(&:path)
          apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
        end

        # @api private
        def apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
          stack = [[:definitions, definitions, data, prefix]]

          until stack.empty?
            kind, *arguments = stack.pop
            case kind
            when :definitions
              current_definitions, current_data, current_prefix = arguments
              next unless current_data.is_a?(Hash)

              current_definitions.reverse_each do |field|
                stack << [:field, field, current_data, current_prefix]
              end
            when :field
              field, current_data, current_prefix = arguments
              next unless current_data.key?(field.name)

              path = [*current_prefix, field.name]
              value = current_data[field.name]
              apply_ruby_predicates_to(field, value, path, messages, error_paths)

              if value.is_a?(Hash)
                stack << [:definitions, field.children, value, path]
              elsif value.is_a?(Array) && field.member
                value.each_index.reverse_each do |index|
                  stack << [:member, field.member, value[index], [*path, index]]
                end
              end
            when :member
              member, value, path = arguments
              apply_ruby_predicates_to(member, value, path, messages, error_paths)
              stack << [:definitions, member.children, value, path]
            end
          end
        end

        # @api private
        def apply_ruby_predicates_to(field, value, path, messages, error_paths)
          return if error_paths.include?(path)

          field.predicates.each do |predicate|
            next if NATIVE_PREDICATES.include?(predicate.name)

            unless predicate_valid?(predicate, value)
              messages << predicate_message(predicate, path)
              error_paths << path
            end
          end
        end

        # @api private
        def predicate_valid?(predicate, value)
          case predicate.name
          when :format then value.respond_to?(:match?) && predicate.argument.match?(value)
          when :included_in then predicate.argument.include?(value)
          when :excluded_from then !predicate.argument.include?(value)
          when :eql then value.eql?(predicate.argument)
          when :not_eql then !value.eql?(predicate.argument)
          else
            raise UnsupportedFeatureError,
                  "predicate #{predicate.name.inspect} is not supported natively; move it to a contract rule"
          end
        end

        # @api private
        def predicate_message(predicate, path)
          text = case predicate.name
                 when :format then 'is in invalid format'
                 when :included_in then "must be one of: #{Array(predicate.argument).join(', ')}"
                 when :excluded_from then "must not be one of: #{Array(predicate.argument).join(', ')}"
                 when :eql then "must be equal to #{predicate.argument}"
                 when :not_eql then "must not be equal to #{predicate.argument}"
                 else 'is invalid'
                 end
          text = @message_backend.message(
            code: predicate.name, predicate: predicate.name, args: [predicate.argument], fallback: text
          )
          Message.new(
            text: text, path: path, code: predicate.name, source: :schema,
            predicate: "#{predicate.name}?", args: [predicate.argument]
          )
        end

        def native_predicate_details(path, code)
          field = field_at_path(path)
          predicate = field&.predicates&.find { |candidate| candidate.name == code.to_sym }
          predicate ? [:"#{predicate.name}?", [predicate.argument]] : [nil, []]
        end

        def field_at_path(path)
          definition = nil

          path.each do |part|
            if part.is_a?(Integer)
              return nil unless definition&.member

              definition = definition.member
            else
              definition = definition ? definition.child_at(part) : @fields_by_name[part.to_sym]
              return nil unless definition
            end
          end

          definition
        end
      end
    end
  end
end
