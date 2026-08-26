# frozen_string_literal: true

module SchemaThroughput
  DEFAULT_UPSTREAM_VERSION = '1.11.1'

  Settings = Data.define(
    :fixed_run_iterations,
    :fixed_run_warmup_iterations,
    :latency_samples,
    :ips_time,
    :ips_warmup,
    :memory_profile_iterations,
    :engine,
    :format,
    :scenario_filter,
    :validate_keys,
    :upstream_version,
    :project_lib
  ) do
    def self.from_environment(environment = ENV)
      new(
        fixed_run_iterations: Integer(environment.fetch('N', '10000')),
        fixed_run_warmup_iterations: Integer(environment.fetch('WARMUP', '1000')),
        latency_samples: Integer(environment.fetch('LATENCY_SAMPLES', '200')),
        ips_time: Float(environment.fetch('IPS_TIME', '5')),
        ips_warmup: Float(environment.fetch('IPS_WARMUP', '2')),
        memory_profile_iterations: Integer(environment.fetch('MEMORY_PROFILE_N', '1000')),
        engine: environment.fetch('ENGINE', 'all'),
        format: environment.fetch('FORMAT', 'text'),
        scenario_filter: environment.fetch('SCENARIO', nil),
        validate_keys: environment.fetch('VALIDATE_KEYS', 'false') == 'true',
        upstream_version: environment.fetch('UPSTREAM_VERSION', DEFAULT_UPSTREAM_VERSION),
        project_lib: File.expand_path('../../lib', __dir__)
      )
    end
  end
end
