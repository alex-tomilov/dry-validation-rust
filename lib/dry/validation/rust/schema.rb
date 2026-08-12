# frozen_string_literal: true

require 'json'
require 'date'
require 'time'
require 'bigdecimal'

module Dry
  module Validation
    module Rust
      class Schema
        TYPES = %i[
          any nil bool true false integer float decimal string symbol array hash
          date date_time datetime time
        ].freeze
        NATIVE_PREDICATES = %i[gt gteq lt lteq min_size max_size size odd even].freeze
        RUBY_PREDICATES = %i[format included_in excluded_from eql not_eql].freeze

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
        attr_reader :mode, :fields, :engine

        # Builds a schema from a DSL block and optional Rust schemas to import.
        def self.define(mode = :schema, *external_schemas, &block)
          dsl = DSL.new(mode: mode)
          external_schemas.each { |schema| dsl.import(schema) }
          dsl.instance_eval(&block) if block
          dsl.compile
        end

        def self.Params(*external_schemas, &) = define(:params, *external_schemas, &)
        def self.JSON(*external_schemas, &) = define(:json, *external_schemas, &)

        # Compiles field definitions into a native schema plan.
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

        # Validates a Hash and returns its output and schema messages.
        def call(input)
          raise ArgumentError, "Input must be a Hash. #{input.class} was given." unless input.is_a?(Hash)

          # Before hooks receive a shallow duplicate; mutating nested values also mutates input.
          prepared_input = ProcessorHooks.apply(before_hooks, input.dup)
          output, native_errors = engine.call(prepared_input)
          output = ProcessorHooks.apply(after_hooks, output)
          messages = native_errors.map do |error|
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

        # Alias for #call.
        alias [] call

        # Returns all declared field paths, including nested array paths.
        def key_paths
          paths_for(fields)
        end

        # Returns a diagnostic representation of this compiled schema.
        def inspect
          "#<#{self.class} mode=#{mode.inspect} fields=#{fields.map(&:name).inspect} native=true>"
        end

        private

        attr_reader :before_hooks, :after_hooks

        def native_message(path, code, text, predicate, args)
          Message.new(
            text: native_error_message(code, text, predicate, args, path),
            path: path, code: code, source: :schema, predicate: predicate, args: args
          )
        end

        def native_error_message(code, native_text, predicate, args, path)
          field = field_at_path(path)
          @message_backend.message(
            code: code, predicate: predicate&.to_s&.delete_suffix('?'), args: args,
            type: field&.normalized_type, fallback: native_text
          )
        end

        def paths_for(definitions, prefix = [])
          definitions.flat_map do |field|
            current = [*prefix, field.name]
            nested = paths_for(field.children, current)
            member_nested = field.member ? paths_for(field.member.children, [*current, :__index__]) : []
            [current, *nested, *member_nested]
          end
        end

        def apply_ruby_predicates(definitions, data, prefix, messages)
          error_paths = messages.to_set(&:path)
          apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
        end

        def apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
          return unless data.is_a?(Hash)

          definitions.each do |field|
            next unless data.key?(field.name)

            path = [*prefix, field.name]
            value = data[field.name]
            unless error_paths.include?(path)
              field.predicates.each do |predicate|
                next if NATIVE_PREDICATES.include?(predicate.name)

                valid = predicate_valid?(predicate, value)
                unless valid
                  messages << predicate_message(predicate, path)
                  error_paths << path
                end
              end
            end

            apply_ruby_predicates_at(field.children, value, path, messages, error_paths) if value.is_a?(Hash)
            next unless value.is_a?(Array) && field.member

            value.each_with_index do |member_value, index|
              member_path = [*path, index]
              field.member.predicates.each do |predicate|
                next if NATIVE_PREDICATES.include?(predicate.name) || error_paths.include?(member_path)

                unless predicate_valid?(predicate, member_value)
                  messages << predicate_message(predicate, member_path)
                  error_paths << member_path
                end
              end
              apply_ruby_predicates_at(field.member.children, member_value, member_path, messages, error_paths)
            end
          end
        end

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
