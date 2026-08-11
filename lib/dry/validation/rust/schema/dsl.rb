# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Schema
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
      end
    end
  end
end
