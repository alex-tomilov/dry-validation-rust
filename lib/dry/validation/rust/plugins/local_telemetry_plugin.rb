# frozen_string_literal: true

require 'json'

module Dry
  module Validation
    module Rust
      module Plugins
        # Appends native validation telemetry as JSON Lines for local inspection.
        class LocalTelemetryPlugin
          # Registers a post-validation callback that appends one JSON record per
          # validation to +path+.
          #
          # @param contract_class [Class] contract class with a declared schema.
          # @param path [#to_path] destination JSON Lines file.
          # @return [Class] the configured contract class.
          # @raise [SystemCallError] if the destination cannot be opened or written.
          def self.install(contract_class, path:)
            contract_class.on_validate(:local_telemetry, after: lambda { |event, payload|
              return unless event == :after_validate

              File.open(path, 'a') do |file|
                file.puts(JSON.generate(record(payload)))
              end
            })
          end

          def self.record(payload)
            {
              'event' => 'after_validate',
              'contract_name' => payload.fetch(:contract_name),
              'success' => payload.fetch(:success),
              'error_count' => payload.fetch(:error_count),
              'duration_ms' => payload.fetch(:duration_ms)
            }
          end
          private_class_method :record
        end
      end
    end
  end
end
