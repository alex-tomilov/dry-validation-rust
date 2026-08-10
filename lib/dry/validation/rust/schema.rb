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

      class ProcessorHooks
        STAGES = %i[value_coercer].freeze

        def self.register(hooks, name, block)
          unless STAGES.include?(name)
            raise ArgumentError, "Undefined step name #{name.inspect}. Available names: #{STAGES.inspect}"
          end
          raise ArgumentError, 'processor hooks require a block' unless block

          hooks << block
        end

        def self.apply(hooks, data)
          hooks.each do |hook|
            replacement = hook.call(data)
            data = replacement if replacement.is_a?(Hash)
          end
          data
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
          attr_accessor :name, :required, :nullable, :filled, :type, :member, :ruby_type
          attr_reader :children, :predicates

          def initialize(name:, required:)
            @name = name&.to_sym
            @required = required
            @nullable = false
            @filled = false
            @type = :any
            @member = nil
            @ruby_type = nil
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

          def add_predicate(name, argument: true)
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
              copy.ruby_type = ruby_type
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
          attr_reader :mode, :fields, :before_hooks, :after_hooks

          def initialize(mode:, fields: [], before_hooks: [], after_hooks: [])
            @mode = mode.to_sym
            @fields = fields
            @before_hooks = before_hooks
            @after_hooks = after_hooks
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
            before_hooks.concat(schema.send(:before_hooks))
            after_hooks.concat(schema.send(:after_hooks))
            self
          end

          def before(name, &block)
            ProcessorHooks.register(before_hooks, name, block)
            self
          end

          def after(name, &block)
            ProcessorHooks.register(after_hooks, name, block)
            self
          end

          def compile(validate_keys: false, messages: MessageConfig.new)
            Schema.new(
              mode: mode, fields: fields, before_hooks: before_hooks, after_hooks: after_hooks,
              validate_keys: validate_keys, messages: messages
            )
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
              nested_value_block? ? nested_target(block) : PredicateBlock.new(definition).instance_eval(&block)
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
            predicates.each { |name, argument| definition.add_predicate(name, argument: argument) }

            if member_type
              member = FieldDefinition.new(name: nil, required: true)
              if member_type.is_a?(Schema)
                member.type = :hash
                member.children = member_type.fields.map(&:deep_dup)
              elsif custom_type?(member_type)
                raise UnsupportedFeatureError,
                      'custom dry-types array members are not supported by the Ruby fallback yet'
              else
                assign_type(member, member_type)
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
              definition.add_predicate(name, argument: argument.nil? || argument)
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
            assign_type(definition, remaining.shift) if remaining.first && type_spec?(remaining.first)

            remaining.each do |predicate|
              case predicate
              when Symbol then definition.add_predicate(predicate)
              when Hash then predicate.each { |name, argument| definition.add_predicate(name, argument: argument) }
              else
                raise UnsupportedFeatureError,
                      "unsupported type or predicate specification: #{predicate.class.name}"
              end
            end
            predicates.each { |name, argument| definition.add_predicate(name, argument: argument) }
          end

          def type_spec?(spec)
            builtin_type?(spec) || custom_type?(spec)
          end

          def assign_type(target, type)
            if builtin_type?(type)
              target.type = type == :datetime ? :date_time : type
            elsif custom_type?(type)
              target.type = :any
              target.ruby_type = type
            else
              raise UnsupportedFeatureError,
                    "unsupported type or predicate specification: #{type.class.name}"
            end
          end

          def builtin_type?(type)
            type.is_a?(Symbol) && TYPES.include?(type)
          end

          def custom_type?(type)
            !type.is_a?(Symbol) && type.respond_to?(:try)
          end

          def nested_value_block?
            definition.type == :hash || (definition.type == :array && definition.member&.type == :hash)
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

        class PredicateBlock
          SINGLE_ARGUMENT_PREDICATES = %i[
            gt gteq lt lteq min_size max_size size format included_in excluded_from eql not_eql
          ].freeze
          ZERO_ARGUMENT_PREDICATES = %i[odd even].freeze

          def initialize(definition)
            @definition = definition
          end

          def method_missing(name, *args, **kwargs, &block)
            if name.to_s.end_with?('?') && block.nil?
              validate_arity(name, args, kwargs)
              argument = if kwargs.empty?
                           args.length <= 1 ? args.first : args
                         else
                           kwargs
                         end
              @definition.add_predicate(name, argument: argument.nil? || argument)
              return self
            end

            raise UnsupportedFeatureError,
                  "unsupported predicate composition expression: #{name.inspect}"
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.end_with?('?') || super
          end

          private

          def validate_arity(name, args, kwargs)
            normalized_name = name.to_s.delete_suffix('?').to_sym
            argument_count = args.length + (kwargs.empty? ? 0 : 1)

            if SINGLE_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 1
              raise ArgumentError, "#{name} expects exactly one argument, got #{argument_count}"
            end

            return unless ZERO_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 0

            raise ArgumentError, "#{name} expects no arguments, got #{argument_count}"
          end
        end

        class RubyTypeProcessor
          def self.apply(definitions, data, messages, message_backend)
            error_paths = messages.to_set(&:path)
            apply_at(definitions, data, [], messages, error_paths, message_backend)
          end

          def self.apply_at(definitions, data, prefix, messages, error_paths, message_backend)
            return unless data.is_a?(Hash)

            definitions.each do |field|
              next unless data.key?(field.name)

              path = [*prefix, field.name]
              if field.ruby_type && !error_paths.include?(path)
                result = field.ruby_type.try(data[field.name])
                data[field.name] = result.input
                unless result.success?
                  messages << Message.new(
                    message_backend.message(code: :type, type: field.type, fallback: 'is invalid'),
                    path: path, code: :type, source: :schema
                  )
                  error_paths << path
                end
              end

              apply_at(field.children, data[field.name], path, messages, error_paths, message_backend)
            end
          end

          private_class_method :apply_at
        end

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
          SchemaResult.new(output, messages.freeze)
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
            native_error_message(code, text, predicate, args, path),
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
            text, path: path, code: predicate.name, source: :schema,
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
