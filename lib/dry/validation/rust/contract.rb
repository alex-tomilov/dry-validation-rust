# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class Contract
        Undefined = Object.new.freeze
        OptionDefinition = Struct.new(:name, :default, :optional, keyword_init: true)

        class << self
          # Copies schema configuration and macros when a contract is inherited.
          def inherited(child)
            super
            child.instance_variable_set(:@config, config.dup)
            child.instance_variable_set(:@macro_registry, MacroRegistry.new(macro_registry))
          end

          # Returns this contract class's configuration.
          def config
            @config ||= Config.new
          end

          # Defines or returns a Params-mode schema for this contract.
          def params(*external_schemas, &)
            define_schema(:params, external_schemas, &)
          end

          # Defines or returns a JSON-mode schema for this contract.
          def json(*external_schemas, &)
            define_schema(:json, external_schemas, &)
          end

          # Defines or returns a schema-mode schema for this contract.
          def schema(*external_schemas, &)
            define_schema(:schema, external_schemas, &)
          end

          # Registers a validation rule for one or more schema paths.
          def rule(*specs, &block)
            paths = specs.flat_map { |spec| Path.expand(spec) }
            ensure_valid_paths(paths) unless paths.empty?
            Rule.new(paths: paths, default_path: default_rule_path(specs, paths), block: block).tap do |new_rule|
              own_rules << new_rule
            end
          end

          # Returns inherited and locally declared rules in execution order.
          def rules
            inherited_rules = superclass.respond_to?(:rules) ? superclass.rules : []
            [*inherited_rules, *own_rules]
          end

          # Returns rules declared directly on this contract class.
          def own_rules
            @own_rules ||= []
          end

          # Declares an injected contract option and its default behavior.
          def option(name, default: Undefined, optional: false, **_options)
            (@option_definitions ||= {})[name.to_sym] = OptionDefinition.new(
              name: name.to_sym,
              default: default,
              optional: optional
            )
            attr_reader name

            self
          end

          # Returns option definitions inherited by this contract class.
          def option_definitions
            inherited = superclass.respond_to?(:option_definitions) ? superclass.option_definitions : {}
            inherited.merge(@option_definitions ||= {})
          end

          # Registers a macro available to rules on this contract class.
          def register_macro(name, *, &)
            macro_registry.register(name, *, &)
            self
          end

          # Returns this contract class's macro registry.
          def macro_registry
            @macro_registry ||= MacroRegistry.new(Rust.global_macros)
          end

          # Enables supported predicates to be resolved as rule macros.
          def import_predicates_as_macros
            @predicates_as_macros = true
            self
          end

          # Builds an anonymous contract instance, optionally configured by a block.
          def build(options = {}, &)
            Class.new(self, &).new(**options)
          end

          # Returns the compiled schema declared by this class or an ancestor.
          def schema_definition
            return @schema_definition if instance_variable_defined?(:@schema_definition)

            superclass.schema_definition if superclass.respond_to?(:schema_definition)
          end

          private

          def define_schema(mode, external_schemas, &block)
            return schema_definition if external_schemas.empty? && block.nil?
            if instance_variable_defined?(:@schema_definition)
              raise DuplicateSchemaError,
                    'Schema has already been defined'
            end

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

          def default_rule_path(specs, paths)
            spec = specs.first
            return paths.first || [] unless specs.length == 1 && spec.is_a?(Hash) && spec.length == 1

            key, value = spec.first
            value.is_a?(Array) ? [key, value] : paths.first || []
          end
        end

        # @return [Hash] context merged into every call to this contract.
        attr_reader :default_context

        # Creates a contract with optional default context and declared options.
        def initialize(default_context: {}, **options)
          @default_context = default_context
          initialize_options(options)
        end

        # Validates input and returns a finalized result, including rule failures.
        def call(input, context = {})
          schema = self.class.schema_definition
          raise SchemaMissingError, "#{self.class} must define a schema" unless schema

          schema_result = schema.call(input)
          shared_context = default_context.merge(context)
          result = Result.new(schema_result, shared_context)
          schema_error_paths = schema_result.messages.to_set(&:path)
          schema_error_path_prefixes = schema_error_paths.each_with_object(Set.new) do |error_path, prefixes|
            (0..error_path.length).each { |length| prefixes << error_path.take(length) }
          end

          self.class.rules.each do |rule|
            if rule.each?
              execute_each(rule, result, shared_context)
            else
              next if rule.paths.any? { |path| dependency_error?(schema_error_paths, schema_error_path_prefixes, path) }

              execute_rule(rule, result, shared_context)
            end
          end

          result.finalize!
        end

        # Alias for #call.
        alias [] call

        # Returns whether a macro can be resolved by this contract.
        def macro_registered?(name)
          self.class.macro_registry.key?(name)
        end

        # Resolves a registered macro by name.
        def resolve_macro(name)
          self.class.macro_registry.fetch(name)
        end

        # Returns a diagnostic representation of the compiled contract.
        def inspect
          "#<#{self.class} schema=#{self.class.schema_definition.inspect} rules=#{self.class.rules.inspect}>"
        end

        private

        def initialize_options(provided)
          definitions = self.class.option_definitions
          unknown = provided.keys - definitions.keys
          if unknown.any?
            raise ArgumentError,
                  "unknown keyword#{'s' if unknown.length > 1}: #{unknown.map(&:inspect).join(', ')}"
          end

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

        def dependency_error?(schema_error_paths, schema_error_path_prefixes, path)
          return true if schema_error_path_prefixes.include?(path)

          path.length.downto(0).any? { |length| schema_error_paths.include?(path.take(length)) }
        end

        def execute_rule(rule, result, context)
          evaluator = Evaluator.new(
            contract: self,
            result: result,
            paths: rule.paths,
            default_path: rule.default_path,
            context: context
          )
          evaluator.execute(rule.block, rule.macro_calls,
                            keyword_params: rule.keyword_params).failures.each do |failure|
            result.add_error(failure)
          end
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
            evaluator.execute(rule.block, rule.macro_calls,
                              keyword_params: rule.keyword_params).failures.each do |failure|
              result.add_error(failure)
            end
          end
        end
      end
    end
  end
end
