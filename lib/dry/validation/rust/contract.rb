# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Contract
        Undefined = Object.new.freeze
        OptionDefinition = Struct.new(:name, :default, :optional, keyword_init: true)

        class << self
          def inherited(child)
            super
            child.instance_variable_set(:@config, config.dup)
            child.instance_variable_set(:@macro_registry, MacroRegistry.new(macro_registry))
          end

          def config
            @config ||= Config.new
          end

          def params(*external_schemas, &block)
            define_schema(:params, external_schemas, &block)
          end

          def json(*external_schemas, &block)
            define_schema(:json, external_schemas, &block)
          end

          def schema(*external_schemas, &block)
            define_schema(:schema, external_schemas, &block)
          end

          def rule(*specs, &block)
            paths = specs.flat_map { |spec| Path.expand(spec) }
            ensure_valid_paths(paths) unless paths.empty?
            Rule.new(paths: paths, block: block).tap { |new_rule| own_rules << new_rule }
          end

          def rules
            inherited_rules = superclass.respond_to?(:rules) ? superclass.rules : []
            [*inherited_rules, *own_rules]
          end

          def own_rules
            @own_rules ||= []
          end

          def option(name, default: Undefined, optional: false, **_options)
            (@option_definitions ||= {})[name.to_sym] = OptionDefinition.new(
              name: name.to_sym,
              default: default,
              optional: optional
            )
            attr_reader name
            self
          end

          def option_definitions
            inherited = superclass.respond_to?(:option_definitions) ? superclass.option_definitions : {}
            inherited.merge(@option_definitions ||= {})
          end

          def register_macro(name, *args, &block)
            macro_registry.register(name, *args, &block)
            self
          end

          def macro_registry
            @macro_registry ||= MacroRegistry.new(Rust.global_macros)
          end

          def import_predicates_as_macros
            @predicates_as_macros = true
            self
          end

          def build(options = {}, &block)
            Class.new(self, &block).new(**options)
          end

          def schema_definition
            return @schema_definition if instance_variable_defined?(:@schema_definition)

            superclass.schema_definition if superclass.respond_to?(:schema_definition)
          end

          private

          def define_schema(mode, external_schemas, &block)
            return schema_definition if external_schemas.empty? && block.nil?
            raise DuplicateSchemaError, "Schema has already been defined" if instance_variable_defined?(:@schema_definition)

            builder = Schema::DSL.new(mode: mode)
            parent = superclass.schema_definition if superclass.respond_to?(:schema_definition)
            builder.import(parent) if parent
            external_schemas.each { |external| builder.import(external) }
            builder.instance_eval(&block) if block
            @schema_definition = builder.compile
          end

          def ensure_valid_paths(paths)
            schema = schema_definition
            raise SchemaMissingError, "#{name || self} must define a schema before rules" unless schema

            valid = schema.key_paths
            invalid = paths.reject do |path|
              valid.any? do |candidate|
                comparable = candidate.reject { |part| part == :__index__ }
                comparable == path || Path.prefix?(comparable, path) || Path.prefix?(path, comparable)
              end
            end
            return if invalid.empty?

            raise InvalidKeysError,
              "#{name || self}.rule specifies keys that are not defined by the schema: #{invalid.inspect}"
          end
        end

        attr_reader :default_context

        def initialize(default_context: {}, **options)
          @default_context = default_context
          initialize_options(options)
        end

        def call(input, context = {})
          schema = self.class.schema_definition
          raise SchemaMissingError, "#{self.class} must define a schema" unless schema

          schema_result = schema.call(input)
          shared_context = default_context.merge(context)
          result = Result.new(schema_result, shared_context)

          self.class.rules.each do |rule|
            if rule.each?
              execute_each(rule, result, shared_context)
            else
              next if rule.paths.any? { |path| dependency_error?(schema_result, path) }

              execute_rule(rule, result, shared_context)
            end
          end

          result.finalize!
        end
        alias [] call

        def macro_registered?(name)
          self.class.macro_registry.key?(name)
        end

        def resolve_macro(name)
          self.class.macro_registry.fetch(name)
        end

        def inspect
          "#<#{self.class} schema=#{self.class.schema_definition.inspect} rules=#{self.class.rules.inspect}>"
        end

        private

        def initialize_options(provided)
          definitions = self.class.option_definitions
          unknown = provided.keys - definitions.keys
          raise ArgumentError, "unknown keyword#{'s' if unknown.length > 1}: #{unknown.map(&:inspect).join(', ')}" if unknown.any?

          definitions.each_value do |definition|
            value = if provided.key?(definition.name)
                      provided[definition.name]
                    elsif !definition.default.equal?(Undefined)
                      definition.default.respond_to?(:call) ? definition.default.call : definition.default
                    elsif definition.optional
                      nil
                    else
                      raise ArgumentError, "missing keyword: :#{definition.name}"
                    end
            instance_variable_set("@#{definition.name}", value)
          end
        end

        def dependency_error?(schema_result, path)
          schema_result.messages.any? do |message|
            Path.prefix?(message.path, path) || Path.prefix?(path, message.path)
          end
        end

        def execute_rule(rule, result, context)
          evaluator = Evaluator.new(contract: self, result: result, paths: rule.paths, context: context)
          evaluator.execute(rule.block, rule.macro_calls).failures.each { |failure| result.add_error(failure) }
        end

        def execute_each(rule, result, context)
          root = rule.paths.first
          collection = Path.fetch(result.to_h, root)
          return if collection.equal?(Path::Undefined) || collection.nil?
          return unless collection.respond_to?(:each_with_index)

          collection.each_with_index do |_item, index|
            item_path = [*root, index]
            next if result.schema_error?(item_path)

            evaluator = Evaluator.new(
              contract: self,
              result: result,
              paths: [item_path],
              context: context,
              index: index
            )
            evaluator.execute(rule.block, rule.macro_calls).failures.each { |failure| result.add_error(failure) }
          end
        end
      end
    end
  end
end
