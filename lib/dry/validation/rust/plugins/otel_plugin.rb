# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      module Plugins
        # Installs OpenTelemetry spans around native schema validation.
        class OtelPlugin
          # @param contract_class [Class] contract class with a declared schema.
          # @param tracer [#start_span] OpenTelemetry-compatible tracer.
          # @return [Class] the configured contract class.
          def self.install(contract_class, tracer: default_tracer)
            contract_class.on_validate(:otel, after: lambda { |event, payload|
              return unless event == :after_validate

              span = tracer.start_span("validate.#{payload.fetch(:contract_name)}")
              span.set_attribute('validation.success', payload.fetch(:success))
              span.set_attribute('validation.error_count', payload.fetch(:error_count))
              span.set_attribute('validation.duration_ms', payload.fetch(:duration_ms))
              span.finish
            })
          end

          def self.default_tracer
            raise LoadError, 'OpenTelemetry is required when no tracer is provided' unless defined?(OpenTelemetry)

            OpenTelemetry.tracer('dry-validation-rust')
          end
          private_class_method :default_tracer
        end
      end
    end
  end
end
