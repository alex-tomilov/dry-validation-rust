# frozen_string_literal: true

require "json"
require "date"
require "time"
require "bigdecimal"

module Dry
  module Validation
    module Rust
      class SchemaResult
        attr_reader :output, :messages

        def initialize(output, messages)
          @output = output
          @messages = messages
        end

        alias to_h output

        def success?
          messages.empty?
        end

        def failure?
          !success?
        end

        def errors(options = {})
          MessageSet.new(messages, options).with(options)
        end

        def error?(spec)
          path = Path.parse(spec)
          messages.any? { |message| Path.prefix?(message.path, path) }
        end

        def [](key)
          output[key]
        end

        def key?(key)
          output.key?(key)
        end
      end

      class Schema
        TYPES = %i[
          any nil bool true false integer float decimal string symbol array hash
          date date_time datetime time
        ].freeze
        NATIVE_PREDICATES = %i[gt gteq lt lteq min_size max_size size odd even].freeze
        RUBY_PREDICATES = %i[format included_in excluded_from eql not_eql].freeze

        Predicate = Struct.new(:name, :argument, keyword_init: true)

        class FieldDefinition
          attr_accessor :name, :required, :nullable, :filled, :type, :member, :children
          attr_reader :predicates

          def initialize(name:, required:)
            @name = name&.to_sym
            @required = required
            @nullable = false
            @filled = false
            @type = :any
            @member = nil
            @children = []
            @predicates = []
          end

          def add_predicate(name, argument = true)
            predicates << Predicate.new(name: name.to_s.delete_suffix("?").to_sym, argument: argument)
          end

          def to_native_h
            {
              name: name&.to_s,
              required: required,
              nullable: nullable,
              filled: filled,
              type: normalized_type.to_s,
              member: member&.to_native_h,
              children: children.map(&:to_native_h),
              predicates: predicates.filter_map do |predicate|
                next unless NATIVE_PREDICATES.include?(predicate.name)

                {name: predicate.name.to_s, argument: predicate.argument}
              end
            }
          end

          def normalized_type
            type == :datetime ? :date_time : type
          end
        end

        class DSL
          attr_reader :mode, :fields

          def initialize(mode:, fields: [])
            @mode = mode.to_sym
            @fields = fields
          end

          def required(name, &block)
            add_field(name, required: true, &block)
          end

          def optional(name, &block)
            add_field(name, required: false, &block)
          end

          def import(schema)
            unless schema.is_a?(Schema)
              raise UnsupportedFeatureError, "only schemas built by Dry::Validation::Rust can be imported"
            end

            fields.concat(schema.fields.map { |field| Marshal.load(Marshal.dump(field)) })
            self
          end

          def before(*_args, &_block)
            raise UnsupportedFeatureError,
              "schema before processor hooks are not supported by the native plan yet"
          end

          def after(*_args, &_block)
            raise UnsupportedFeatureError,
              "schema after processor hooks are not supported by the native plan yet"
          end

          def compile
            Schema.new(mode: mode, fields: fields)
          end

          private

          def add_field(name, required:, &block)
            unless name.is_a?(Symbol)
              raise ArgumentError, "Key +#{name}+ is not a symbol"
            end
            if fields.any? { |field| field.name == name }
              raise ArgumentError, "key #{name.inspect} is already defined"
            end

            definition = FieldDefinition.new(name: name, required: required)
            fields << definition
            builder = FieldBuilder.new(definition, mode: mode)
            builder.value(&block) if block
            builder
          end
        end

        class FieldBuilder
          attr_reader :definition, :mode

          def initialize(definition, mode:)
            @definition = definition
            @mode = mode
          end

          def value(*specs, **predicates, &block)
            apply_specs(specs, predicates)
            if block
              unless definition.type == :hash || (definition.type == :array && definition.member&.type == :hash)
                raise UnsupportedFeatureError,
                  "predicate composition blocks are not supported yet; use named predicates or a contract rule"
              end
              nested_target(block)
            end
            self
          end

          def filled(*specs, **predicates, &block)
            definition.filled = true
            value(*specs, **predicates, &block)
          end

          def maybe(*specs, **predicates, &block)
            definition.nullable = true
            value(*specs, **predicates, &block)
          end

          def hash(schema = nil, &block)
            definition.type = :hash
            nested = DSL.new(mode: mode)
            nested.import(schema) if schema
            nested.instance_eval(&block) if block
            definition.children = nested.fields
            self
          end

          def array(member_type = nil, **predicates, &block)
            definition.type = :array
            predicates.each { |name, argument| definition.add_predicate(name, argument) }

            if member_type
              member = FieldDefinition.new(name: nil, required: true)
              if member_type.is_a?(Schema)
                member.type = :hash
                member.children = member_type.fields.map { |field| Marshal.load(Marshal.dump(field)) }
              else
                member.type = normalize_type(member_type)
              end
              definition.member = member
            end

            if block
              definition.member ||= FieldDefinition.new(name: nil, required: true)
              definition.member.type = :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.member.children = nested.fields
            end
            self
          end

          def each(member_type = nil, **predicates, &block)
            array(member_type, **predicates, &block)
          end

          def method_missing(name, *args, **kwargs, &block)
            if name.to_s.end_with?("?") && block.nil?
              argument = kwargs.empty? ? (args.length <= 1 ? args.first : args) : kwargs
              definition.add_predicate(name, argument.nil? ? true : argument)
              return self
            end

            super
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?("?") || super
          end

          private

          def apply_specs(specs, predicates)
            remaining = specs.dup
            if remaining.first && type_spec?(remaining.first)
              definition.type = normalize_type(remaining.shift)
            end

            remaining.each do |predicate|
              case predicate
              when Symbol then definition.add_predicate(predicate)
              when Hash then predicate.each { |name, argument| definition.add_predicate(name, argument) }
              else
                raise UnsupportedFeatureError,
                  "unsupported type or predicate specification: #{predicate.class.name}"
              end
            end
            predicates.each { |name, argument| definition.add_predicate(name, argument) }
          end

          def type_spec?(spec)
            spec.is_a?(Symbol) && TYPES.include?(spec)
          end

          def normalize_type(type)
            unless type_spec?(type)
              raise UnsupportedFeatureError,
                "custom dry-types objects are not supported by the native plan yet (got #{type.inspect})"
            end

            type == :datetime ? :date_time : type
          end

          def nested_target(block)
            if definition.type == :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.children = nested.fields
            else
              definition.member ||= FieldDefinition.new(name: nil, required: true)
              definition.member.type = :hash
              nested = DSL.new(mode: mode)
              nested.instance_eval(&block)
              definition.member.children = nested.fields
            end
          end
        end

        attr_reader :mode, :fields, :engine

        def self.define(mode = :schema, *external_schemas, &block)
          dsl = DSL.new(mode: mode)
          external_schemas.each { |schema| dsl.import(schema) }
          dsl.instance_eval(&block) if block
          dsl.compile
        end

        def self.Params(*external_schemas, &block)
          define(:params, *external_schemas, &block)
        end

        def self.JSON(*external_schemas, &block)
          define(:json, *external_schemas, &block)
        end

        def initialize(mode:, fields:)
          @mode = mode.to_sym
          @fields = fields.freeze
          plan = {engine_version: ENGINE_VERSION, mode: mode.to_s, fields: fields.map(&:to_native_h)}
          @engine = Native::Engine.new(JSON.generate(plan))
        rescue StandardError => error
          raise NativeExtensionError, "could not compile native schema plan: #{error.message}"
        end

        def call(input)
          raise ArgumentError, "Input must be a Hash. #{input.class} was given." unless input.is_a?(Hash)

          output, native_errors = engine.call(input)
          messages = native_errors.map do |path, code, text|
            Message.new(text, path: path, code: code, source: :schema)
          end
          apply_ruby_predicates(fields, output, [], messages)
          SchemaResult.new(output, messages.freeze)
        end
        alias [] call

        def key_paths
          paths_for(fields)
        end

        def inspect
          "#<#{self.class} mode=#{mode.inspect} fields=#{fields.map(&:name).inspect} native=true>"
        end

        private

        def paths_for(definitions, prefix = [])
          definitions.flat_map do |field|
            current = [*prefix, field.name]
            nested = paths_for(field.children, current)
            member_nested = field.member ? paths_for(field.member.children, [*current, :__index__]) : []
            [current, *nested, *member_nested]
          end
        end

        def apply_ruby_predicates(definitions, data, prefix, messages)
          return unless data.is_a?(Hash)

          definitions.each do |field|
            next unless data.key?(field.name)

            path = [*prefix, field.name]
            value = data[field.name]
            unless schema_error_at?(messages, path)
              field.predicates.each do |predicate|
                next if NATIVE_PREDICATES.include?(predicate.name)

                valid = predicate_valid?(predicate, value)
                messages << predicate_message(predicate, path) unless valid
              end
            end

            apply_ruby_predicates(field.children, value, path, messages) if value.is_a?(Hash)
            next unless value.is_a?(Array) && field.member

            value.each_with_index do |member_value, index|
              member_path = [*path, index]
              field.member.predicates.each do |predicate|
                next if NATIVE_PREDICATES.include?(predicate.name) || schema_error_at?(messages, member_path)

                messages << predicate_message(predicate, member_path) unless predicate_valid?(predicate, member_value)
              end
              apply_ruby_predicates(field.member.children, member_value, member_path, messages)
            end
          end
        end

        def schema_error_at?(messages, path)
          messages.any? { |message| message.path == path }
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
                 when :format then "is in invalid format"
                 when :included_in then "must be one of: #{Array(predicate.argument).join(', ')}"
                 when :excluded_from then "must not be one of: #{Array(predicate.argument).join(', ')}"
                 when :eql then "must be equal to #{predicate.argument}"
                 when :not_eql then "must not be equal to #{predicate.argument}"
                 else "is invalid"
                 end
          Message.new(text, path: path, code: predicate.name, source: :schema)
        end
      end
    end
  end
end
