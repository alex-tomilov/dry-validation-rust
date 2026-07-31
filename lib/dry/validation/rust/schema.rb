# frozen_string_literal: true

require 'json'
require 'date'
require 'time'
require 'bigdecimal'

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

        # Private Rust-to-Ruby error buffer format. Rust reads VERSION from
        # this class so this is the single authority for its metadata.
        NATIVE_ERROR_BUFFER_VERSION = 1
        NATIVE_ERROR_BUFFER_HEADER_SIZE = 1
        NATIVE_ERROR_RECORD_PATH_LENGTH_SIZE = 1
        NATIVE_ERROR_RECORD_CODE_OFFSET = 0
        NATIVE_ERROR_RECORD_TEXT_OFFSET = 1
        NATIVE_ERROR_RECORD_TRAILER_SIZE = 2

        Predicate = Struct.new(:name, :argument, keyword_init: true)

        class FieldDefinition
          attr_accessor :name, :required, :nullable, :filled, :type, :member
          attr_reader :children, :predicates

          def initialize(name:, required:)
            @name = name&.to_sym
            @required = required
            @nullable = false
            @filled = false
            @type = :any
            @member = nil
            @children = []
            @children_by_name = {}
            @predicates = []
          end

          def children=(children)
            @children = children
            @children_by_name = children.to_h { |child| [child.name, child] }
          end

          def child_at(name)
            @children_by_name[name.to_sym]
          end

          def add_predicate(name, argument = true)
            normalized_name = name.to_s.delete_suffix('?').to_sym
            unless (NATIVE_PREDICATES | RUBY_PREDICATES).include?(normalized_name)
              raise UnsupportedFeatureError,
                    "predicate #{normalized_name.inspect} is not supported natively; move it to a contract rule"
            end

            predicates << Predicate.new(name: normalized_name, argument: argument)
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

                { name: predicate.name.to_s, argument: predicate.argument }
              end
            }
          end

          def normalized_type
            type == :datetime ? :date_time : type
          end

          def deep_dup
            self.class.new(name: name, required: required).tap do |copy|
              copy.nullable = nullable
              copy.filled = filled
              copy.type = type
              copy.member = member&.deep_dup
              copy.children = children.map(&:deep_dup)
              predicates.each do |predicate|
                copy.predicates << Predicate.new(name: predicate.name, argument: duplicate_value(predicate.argument))
              end
            end
          end

          private

          def duplicate_value(value)
            case value
            when Array
              value.map { |item| duplicate_value(item) }
            when Hash
              value.each_with_object({}) do |(key, item), copy|
                copy[duplicate_value(key)] = duplicate_value(item)
              end
            else
              value.dup
            end
          rescue TypeError
            value
          end
        end

        class DSL
          attr_reader :mode, :fields

          def initialize(mode:, fields: [])
            @mode = mode.to_sym
            @fields = fields
          end

          def required(name, &)
            add_field(name, required: true, &)
          end

          def optional(name, &)
            add_field(name, required: false, &)
          end

          def import(schema)
            unless schema.is_a?(Schema)
              raise UnsupportedFeatureError, 'only schemas built by Dry::Validation::Rust can be imported'
            end

            schema.fields.each do |field|
              if fields.any? { |existing| existing.name == field.name }
                raise ArgumentError, "key #{field.name.inspect} is already defined"
              end

              fields << field.deep_dup
            end
            self
          end

          def before(*_args, &)
            raise UnsupportedFeatureError,
                  'schema before processor hooks are not supported by the native plan yet'
          end

          def after(*_args, &)
            raise UnsupportedFeatureError,
                  'schema after processor hooks are not supported by the native plan yet'
          end

          def compile
            Schema.new(mode: mode, fields: fields)
          end

          private

          def add_field(name, required:, &block)
            raise ArgumentError, "Key +#{name}+ is not a symbol" unless name.is_a?(Symbol)
            raise ArgumentError, "key #{name.inspect} is already defined" if fields.any? { |field| field.name == name }

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
                      'predicate composition blocks are not supported yet; use named predicates or a contract rule'
              end
              nested_target(block)
            end
            self
          end

          def filled(*specs, **predicates, &)
            definition.filled = true
            value(*specs, **predicates, &)
          end

          def maybe(*specs, **predicates, &)
            definition.nullable = true
            value(*specs, **predicates, &)
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
                member.children = member_type.fields.map(&:deep_dup)
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

          def each(member_type = nil, **predicates, &)
            array(member_type, **predicates, &)
          end

          def method_missing(name, *args, **kwargs, &block)
            if name.to_s.end_with?('?') && block.nil?
              argument = if kwargs.empty?
                           args.length <= 1 ? args.first : args
                         else
                           kwargs
                         end
              definition.add_predicate(name, argument.nil? || argument)
              return self
            end

            super
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?('?') || super
          end

          private

          def apply_specs(specs, predicates)
            remaining = specs.dup
            definition.type = normalize_type(remaining.shift) if remaining.first && type_spec?(remaining.first)

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

        def self.Params(*external_schemas, &)
          define(:params, *external_schemas, &)
        end

        def self.JSON(*external_schemas, &)
          define(:json, *external_schemas, &)
        end

        def initialize(mode:, fields:)
          @mode = mode.to_sym
          @fields = fields.freeze
          plan = { engine_version: ENGINE_VERSION, mode: mode.to_s, fields: fields.map(&:to_native_h) }
          @engine = Native::Engine.new(JSON.generate(plan))
        rescue StandardError => e
          raise NativeExtensionError, "could not compile native schema plan: #{e.message}"
        end

        def call(input)
          raise ArgumentError, "Input must be a Hash. #{input.class} was given." unless input.is_a?(Hash)

          output, native_errors = engine.call(input)
          messages = native_errors_to_messages(native_errors)
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

        def native_errors_to_messages(native_errors)
          unless native_errors.fetch(0) == NATIVE_ERROR_BUFFER_VERSION
            raise NativeExtensionError,
                  "unsupported native error buffer version: #{native_errors.first.inspect}"
          end

          messages = []
          offset = NATIVE_ERROR_BUFFER_HEADER_SIZE

          while offset < native_errors.length
            path_length = native_errors.fetch(offset)
            unless path_length.is_a?(Integer) && path_length >= 0
              raise NativeExtensionError, 'malformed native error buffer'
            end

            path_start = offset + NATIVE_ERROR_RECORD_PATH_LENGTH_SIZE
            trailer_start = path_start + path_length
            record_end = trailer_start + NATIVE_ERROR_RECORD_TRAILER_SIZE
            raise NativeExtensionError, 'malformed native error buffer' if record_end > native_errors.length

            path = native_errors.slice(path_start, path_length)
            code = native_errors.fetch(trailer_start + NATIVE_ERROR_RECORD_CODE_OFFSET)
            text = native_errors.fetch(trailer_start + NATIVE_ERROR_RECORD_TEXT_OFFSET)
            offset = record_end
            unless path.all? { |part| part.is_a?(Symbol) || part.is_a?(Integer) } &&
                   code.is_a?(Symbol) && text.is_a?(String)
              raise NativeExtensionError, 'malformed native error buffer'
            end

            predicate, args = native_predicate_details(path, code)
            messages << Message.new(
              text, path: path, code: code, source: :schema,
                    predicate: predicate, args: args
            )
          end

          messages
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
          Message.new(
            text, path: path, code: predicate.name, source: :schema,
                  predicate: "#{predicate.name}?", args: [predicate.argument]
          )
        end

        def native_predicate_details(path, code)
          field = field_at_path(fields, path)
          predicate = field&.predicates&.find { |candidate| candidate.name == code.to_sym }
          predicate ? [:"#{predicate.name}?", [predicate.argument]] : [nil, []]
        end

        def field_at_path(definitions, path)
          definition = nil

          path.each do |part|
            if part.is_a?(Integer)
              return unless definition&.member

              definition = definition.member
            else
              definition = if definition
                             definition.child_at(part)
                           else
                             definitions.find { |field| field.name == part.to_sym }
                           end
              return unless definition
            end
          end

          definition
        end
      end
    end
  end
end
