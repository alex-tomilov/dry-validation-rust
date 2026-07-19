# frozen_string_literal: true

require "etc"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rbconfig"
require "shellwords"
require "tmpdir"
require "time"

require_relative "statistics"
require_relative "workloads"

module DryValidationRustBenchmark
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class EvidenceError < Error; end

  class Configuration
    MODES = {
      "quick" => {runs: 1, iterations: 50, warmup_iterations: 10},
      "full" => {runs: 5, iterations: 10_000, warmup_iterations: 1_000}
    }.freeze
    DISTRIBUTIONS = %w[valid invalid mixed].freeze
    ENGINES = %w[rust upstream].freeze

    attr_reader :mode, :output, :runs, :iterations, :warmup_iterations,
                :workloads, :distributions, :engines

    def self.parse(argv)
      new.tap { |configuration| configuration.parse!(argv.dup) }
    end

    def initialize
      @mode = nil
      @output = nil
      @force = false
      @allow_dirty = false
      @workloads = []
      @distributions = []
      @engines = []
    end

    def parse!(argv)
      parser = OptionParser.new do |options|
        options.banner = "Usage: script/benchmark-suite --mode MODE --output PATH [options]"
        options.on("--mode MODE", MODES.keys, "quick or full") { |value| @mode = value }
        options.on("--output PATH") { |value| @output = File.expand_path(value) }
        options.on("--runs N", Integer) { |value| @runs = value }
        options.on("--iterations N", Integer) { |value| @iterations = value }
        options.on("--warmup N", Integer) { |value| @warmup_iterations = value }
        options.on("--workload NAME", Workloads.all.keys) { |value| @workloads << value }
        options.on("--distribution NAME", DISTRIBUTIONS) { |value| @distributions << value }
        options.on("--engine NAME", ["all", *ENGINES]) { |value| @engines.concat(value == "all" ? ENGINES : [value]) }
        options.on("--force", "replace an existing output directory") { @force = true }
        options.on("--allow-dirty", "permit full evidence from a dirty tree and label it") { @allow_dirty = true }
        options.on("-h", "--help") do
          puts options
          exit 0
        end
      end
      parser.parse!(argv)
      raise ConfigurationError, "unexpected arguments: #{argv.join(" ")}" unless argv.empty?
      raise ConfigurationError, "--mode is required" unless @mode
      raise ConfigurationError, "--output is required" unless @output

      defaults = MODES.fetch(@mode)
      @runs ||= defaults.fetch(:runs)
      @iterations ||= defaults.fetch(:iterations)
      @warmup_iterations ||= defaults.fetch(:warmup_iterations)
      @workloads = Workloads.all.keys if @workloads.empty?
      @distributions = DISTRIBUTIONS.dup if @distributions.empty?
      @engines = ENGINES.dup if @engines.empty?
      @workloads.uniq!
      @distributions.uniq!
      @engines.uniq!

      raise ConfigurationError, "--runs must be positive" unless @runs.positive?
      raise ConfigurationError, "--iterations must be positive" unless @iterations.positive?
      raise ConfigurationError, "--warmup must be non-negative" if @warmup_iterations.negative?
      validate_full_mode! if @mode == "full"

      self
    rescue OptionParser::ParseError => error
      raise ConfigurationError, error.message
    end

    def force?
      @force
    end

    def allow_dirty?
      @allow_dirty
    end

    def authoritative?
      mode == "full"
    end

    private

    def validate_full_mode!
      defaults = MODES.fetch("full")
      raise ConfigurationError, "full mode requires at least 5 runs" if @runs < defaults.fetch(:runs)
      raise ConfigurationError, "full mode requires at least 10000 iterations" if @iterations < defaults.fetch(:iterations)
      raise ConfigurationError, "full mode requires at least 1000 warmup iterations" if @warmup_iterations < defaults.fetch(:warmup_iterations)

      complete_matrix = @workloads.sort == Workloads.all.keys.sort &&
        @distributions.sort == DISTRIBUTIONS.sort &&
        @engines.sort == ENGINES.sort
      return if complete_matrix

      raise ConfigurationError, "full mode requires the complete workload, distribution, and engine matrix"
    end
  end

  module Summarizer
    METRICS = %w[elapsed_seconds throughput_per_second allocated_objects peak_rss_kib].freeze
    module_function

    def build(raw_results, mode:, environment:)
      validate_equivalence!(raw_results)
      groups = raw_results.group_by { |result| [result.fetch("workload"), result.fetch("distribution"), result.fetch("engine")] }
      summaries = groups.sort.to_h do |(workload, distribution, engine), samples|
        metrics = METRICS.to_h do |metric|
          values = samples.filter_map { |sample| sample[metric] }
          [metric, values.empty? ? nil : Statistics.spread(values)]
        end
        [group_key(workload, distribution, engine), {
          "workload" => workload,
          "distribution" => distribution,
          "engine" => engine,
          "runs" => samples.length,
          "iterations_per_run" => samples.map { |sample| sample.fetch("iterations") }.uniq,
          "warmup_iterations_per_run" => samples.map { |sample| sample.fetch("warmup_iterations") }.uniq,
          "metrics" => metrics,
          "outcome_checksum" => samples.map { |sample| sample.fetch("outcome_checksum") }.uniq.fetch(0)
        }]
      end

      comparisons = summaries.values
        .group_by { |summary| [summary.fetch("workload"), summary.fetch("distribution")] }
        .filter_map do |(workload, distribution), engine_summaries|
          by_engine = engine_summaries.to_h { |summary| [summary.fetch("engine"), summary] }
          next unless by_engine.keys.sort == ["dry-validation", "dry-validation-rust"]

          rust = by_engine.fetch("dry-validation-rust").fetch("metrics")
          upstream = by_engine.fetch("dry-validation").fetch("metrics")
          {
            "workload" => workload,
            "distribution" => distribution,
            "rust_to_upstream_throughput_ratio" => ratio(rust, upstream, "throughput_per_second"),
            "rust_to_upstream_allocation_ratio" => ratio(rust, upstream, "allocated_objects"),
            "rust_to_upstream_peak_rss_ratio" => ratio(rust, upstream, "peak_rss_kib")
          }
        end

      {
        "schema_version" => 1,
        "benchmark" => "dry-validation-rust comparative suite",
        "mode" => mode,
        "authoritative" => environment.fetch("authoritative"),
        "quick_mode_notice" => mode == "quick" ? "Quick mode is smoke evidence only and is not suitable for publication claims." : nil,
        "commit_sha" => environment.fetch("commit_sha"),
        "dirty_tree" => environment.fetch("dirty_tree"),
        "groups" => summaries,
        "comparisons" => comparisons
      }
    end

    def validate_equivalence!(raw_results)
      raw_results.group_by { |result| [result.fetch("workload"), result.fetch("distribution"), result.fetch("run")] }.each do |key, samples|
        next if samples.length == 1

        checksums = samples.map { |sample| sample.fetch("outcome_checksum") }.uniq
        counts = samples.map do |sample|
          [sample.fetch("processed_count"), sample.fetch("success_count"), sample.fetch("failure_count")]
        end.uniq
        next if checksums.one? && counts.one?

        raise EvidenceError, "engine outcomes differ for #{key.join("/")}"
      end
    end

    def ratio(numerator_metrics, denominator_metrics, metric)
      numerator = numerator_metrics[metric]&.fetch("median")
      denominator = denominator_metrics[metric]&.fetch("median")
      return nil unless numerator && denominator && !denominator.zero?

      numerator.to_f / denominator
    end

    def group_key(workload, distribution, engine)
      [workload, distribution, engine].join("/")
    end
  end

  class Suite
    PROJECT_ROOT = File.expand_path("../..", __dir__)
    WORKER = File.join(PROJECT_ROOT, "benchmark/worker.rb")
    SANITIZED_ENVIRONMENT_KEYS = %w[
      BUNDLE_BIN_PATH BUNDLE_GEMFILE BUNDLER_VERSION RUBYLIB RUBYOPT
    ].freeze
    RECORDED_ENVIRONMENT_KEYS = %w[
      MALLOC_ARENA_MAX RUBY_GC_HEAP_GROWTH_FACTOR RUBY_GC_HEAP_INIT_SLOTS RUSTFLAGS
    ].freeze

    def initialize(configuration)
      @configuration = configuration
    end

    def call
      environment = environment_metadata
      if @configuration.authoritative? && environment.fetch("dirty_tree") && !@configuration.allow_dirty?
        raise EvidenceError, "full mode requires a clean tree; commit/stash changes or pass --allow-dirty to label them"
      end
      if @configuration.authoritative? && !gnu_time_available?
        raise EvidenceError, "full mode requires GNU /usr/bin/time with maximum-RSS support"
      end
      if @configuration.authoritative? && (!environment.fetch("rust") || !environment.fetch("cargo"))
        raise EvidenceError, "full mode requires Rust and Cargo version metadata"
      end

      prepare_output!
      @evidence_authoritative = environment.fetch("authoritative")
      raw_results = run_workers
      summary = Summarizer.build(raw_results, mode: @configuration.mode, environment: environment)
      write_evidence(environment, raw_results, summary)
      summary
    end

    def prepare_output!
      path = @configuration.output
      if File.exist?(path)
        raise EvidenceError, "output already exists: #{path}; pass --force to replace it" unless @configuration.force?

        refuse_unsafe_output!(path)
        FileUtils.remove_entry(path)
      end
      FileUtils.mkdir_p(File.join(path, "raw"))
    end

    private

    def run_workers
      results = []
      @configuration.workloads.each do |workload|
        @configuration.distributions.each do |distribution|
          1.upto(@configuration.runs) do |run|
            engine_order = run.odd? ? @configuration.engines : @configuration.engines.reverse
            paired = engine_order.map.with_index do |engine, order_index|
              result = run_worker(engine, workload, distribution)
              result.merge(
                "mode" => @configuration.mode,
                "authoritative" => @evidence_authoritative,
                "run" => run,
                "engine_order" => order_index + 1,
                "exit_status" => 0
              )
            end
            Summarizer.validate_equivalence!(paired)
            results.concat(paired)
          end
        end
      end
      results
    end

    def run_worker(engine, workload, distribution)
      arguments = [
        RbConfig.ruby,
        WORKER,
        "--engine", engine,
        "--workload", workload,
        "--distribution", distribution,
        "--iterations", @configuration.iterations.to_s,
        "--warmup", @configuration.warmup_iterations.to_s
      ]
      stdout, stderr, status, peak_rss = capture_with_rss(arguments)
      unless status.success?
        raise EvidenceError, "#{engine}/#{workload}/#{distribution} worker failed (#{status.exitstatus}): #{stderr}"
      end
      raise EvidenceError, "#{engine}/#{workload}/#{distribution} wrote unexpected stderr: #{stderr}" unless stderr.empty?

      JSON.parse(stdout).merge(
        "peak_rss_kib" => peak_rss,
        "rss_source" => peak_rss ? "GNU /usr/bin/time %M" : "unavailable on this platform",
        "rss_unit" => "KiB"
      )
    rescue JSON::ParserError => error
      raise EvidenceError, "#{engine}/#{workload}/#{distribution} returned invalid JSON: #{error.message}"
    end

    def capture_with_rss(arguments)
      command = arguments
      rss_path = nil
      if gnu_time_available?
        rss_directory = Dir.mktmpdir("dvr-benchmark-rss")
        rss_path = File.join(rss_directory, "maximum-rss-kib")
        command = ["/usr/bin/time", "--format", "%M", "--output", rss_path, *arguments]
      end

      stdout, stderr, status = Open3.capture3(child_environment, *command, chdir: PROJECT_ROOT)
      peak_rss = rss_path && status.success? ? Integer(File.read(rss_path).strip, 10) : nil
      [stdout, stderr, status, peak_rss]
    ensure
      FileUtils.remove_entry(File.dirname(rss_path)) if rss_path && File.exist?(File.dirname(rss_path))
    end

    def child_environment
      SANITIZED_ENVIRONMENT_KEYS.to_h { |key| [key, nil] }
    end

    def gnu_time_available?
      return @gnu_time_available unless @gnu_time_available.nil?

      _stdout, _stderr, status = Open3.capture3("/usr/bin/time", "--version")
      @gnu_time_available = status.success?
    rescue Errno::ENOENT
      @gnu_time_available = false
    end

    def environment_metadata
      commit_sha, dirty_tree = git_metadata
      {
        "schema_version" => 1,
        "commit_sha" => commit_sha,
        "dirty_tree" => dirty_tree,
        "benchmark_mode" => @configuration.mode,
        "authoritative" => @configuration.authoritative? && !dirty_tree,
        "os" => RbConfig::CONFIG.fetch("host_os"),
        "kernel" => command_output("uname", "-sr"),
        "architecture" => command_output("uname", "-m"),
        "cpu_model" => cpu_model,
        "cpu_count" => Etc.nprocessors,
        "ruby" => RUBY_DESCRIPTION,
        "rust" => optional_command_output("rustc", "--version"),
        "cargo" => optional_command_output("cargo", "--version"),
        "gem_versions" => {
          "dry-validation-rust" => DryValidationRustBenchmark.project_version,
          "dry-validation" => "1.11.1",
          "dry-schema" => "1.16.0"
        },
        "configuration" => {
          "runs" => @configuration.runs,
          "iterations" => @configuration.iterations,
          "warmup_iterations" => @configuration.warmup_iterations,
          "workloads" => @configuration.workloads,
          "distributions" => @configuration.distributions,
          "engines" => @configuration.engines
        },
        "environment_variables" => RECORDED_ENVIRONMENT_KEYS.filter_map do |key|
          [key, ENV.fetch(key)] if ENV.key?(key)
        end.to_h,
        "rss" => {
          "source" => gnu_time_available? ? "GNU /usr/bin/time %M around each worker process" : "unavailable",
          "unit" => "KiB",
          "platform_note" => "GNU time reports maximum resident set size in KiB on Linux; unavailable sources are not compared."
        }
      }
    end

    def cpu_model
      if File.file?("/proc/cpuinfo")
        line = File.foreach("/proc/cpuinfo").find { |candidate| candidate.start_with?("model name") }
        return line.split(":", 2).last.strip if line
      end
      optional_command_output("sysctl", "-n", "machdep.cpu.brand_string") || "unknown"
    end

    def git_metadata
      commit_sha = optional_command_output("git", "rev-parse", "HEAD")
      if commit_sha
        dirty_output = command_output("git", "status", "--porcelain", "--untracked-files=normal")
        return [commit_sha, !dirty_output.empty?]
      end

      revision = ENV.fetch("DVR_IMAGE_REVISION", "")
      dirty = revision.empty? || revision.end_with?("-dirty")
      sha = revision.delete_suffix("-dirty")
      sha = "unavailable" unless sha.match?(/\A[0-9a-f]{40}\z/)
      [sha, dirty]
    end

    def command_output(*command)
      stdout, stderr, status = Open3.capture3(*command, chdir: PROJECT_ROOT)
      raise EvidenceError, "#{command.join(" ")} failed: #{stderr}" unless status.success?

      stdout.strip
    end

    def optional_command_output(*command)
      command_output(*command)
    rescue Errno::ENOENT, EvidenceError
      nil
    end

    def write_evidence(environment, raw_results, summary)
      raw_results.each do |result|
        filename = format(
          "%s-%s-%s-run-%02d.json",
          result.fetch("engine").tr("-", "_"),
          result.fetch("workload"),
          result.fetch("distribution"),
          result.fetch("run")
        )
        write_json(File.join(@configuration.output, "raw", filename), result)
      end
      write_json(File.join(@configuration.output, "environment.json"), environment)
      write_json(File.join(@configuration.output, "summary.json"), summary)
      File.write(File.join(@configuration.output, "summary.md"), summary_markdown(summary))
      File.write(File.join(@configuration.output, "README.md"), evidence_readme(summary))
      reproduce = File.join(@configuration.output, "reproduce.sh")
      File.write(reproduce, reproduce_script)
      FileUtils.chmod(0o755, reproduce)
    end

    def write_json(path, payload)
      File.write(path, JSON.pretty_generate(payload) + "\n")
    end

    def summary_markdown(summary)
      warning = if summary.fetch("mode") == "quick"
        "> Quick mode is smoke evidence only and must not be used for publication claims.\n\n"
      elsif summary.fetch("dirty_tree")
        "> This full run came from a dirty tree and must not be attributed to the recorded commit alone.\n\n"
      else
        ""
      end
      rows = summary.fetch("comparisons").map do |comparison|
        throughput = format_ratio(comparison.fetch("rust_to_upstream_throughput_ratio"))
        allocations = format_ratio(comparison.fetch("rust_to_upstream_allocation_ratio"))
        rss = format_ratio(comparison.fetch("rust_to_upstream_peak_rss_ratio"))
        "| #{comparison.fetch("workload")} | #{comparison.fetch("distribution")} | #{throughput} | #{allocations} | #{rss} |"
      end
      measurement_rows = summary.fetch("groups").values.map do |group|
        metrics = group.fetch("metrics")
        throughput = format_spread(metrics.fetch("throughput_per_second"), decimals: 1)
        allocations = format_spread(metrics.fetch("allocated_objects"), decimals: 0)
        rss = format_spread(metrics.fetch("peak_rss_kib"), decimals: 0)
        "| #{group.fetch("workload")} | #{group.fetch("distribution")} | #{group.fetch("engine")} | #{throughput} | #{allocations} | #{rss} |"
      end
      <<~MARKDOWN
        # Benchmark summary

        #{warning}Mode: `#{summary.fetch("mode")}`. Commit: `#{summary.fetch("commit_sha")}`.

        Each measurement is the median followed by the minimum-maximum range across independent runs.

        | Workload | Distribution | Engine | Throughput/s | Allocated objects | Peak RSS (KiB) |
        | --- | --- | --- | ---: | ---: | ---: |
        #{measurement_rows.join("\n")}

        Ratios are Rust-backed medians divided by upstream medians for the same workload and distribution. Lower is better for allocation and RSS ratios; higher is better for throughput.

        | Workload | Distribution | Throughput ratio | Allocation ratio | Peak RSS ratio |
        | --- | --- | ---: | ---: | ---: |
        #{rows.join("\n")}

        Raw per-run values, medians, minima, and maxima are retained in `raw/` and `summary.json`. These synthetic scenarios are workload-specific. The Rust-backed engine still operates on Ruby objects under the GVL.
      MARKDOWN
    end

    def evidence_readme(summary)
      <<~MARKDOWN
        # Benchmark evidence package

        This directory was generated by `script/benchmark-suite` in `#{summary.fetch("mode")}` mode for commit `#{summary.fetch("commit_sha")}`.

        - `environment.json` records the toolchain, platform, CPU, commit, dirty-tree state, and benchmark configuration.
        - `raw/` contains every isolated worker result.
        - `summary.json` and `summary.md` are mechanically derived from those raw results.
        - `reproduce.sh` reruns the same mode with the repository defaults.

        Results apply only to the named synthetic workloads and environment. They are not evidence of a universal Rust speedup. The current engine operates under the GVL.
      MARKDOWN
    end

    def reproduce_script
      mode = @configuration.mode
      output = relative_output_argument
      <<~BASH
        #!/usr/bin/env bash
        set -euo pipefail

        project_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
        cd "$project_root"

        exec script/benchmark-suite --mode #{mode} --output #{output} --force
      BASH
    end

    def format_ratio(value)
      value ? format("%.3fx", value) : "unavailable"
    end

    def format_spread(spread, decimals:)
      return "unavailable" unless spread

      formatter = decimals.zero? ? "%.0f" : "%.#{decimals}f"
      median = format(formatter, spread.fetch("median"))
      minimum = format(formatter, spread.fetch("min"))
      maximum = format(formatter, spread.fetch("max"))
      "#{median} (#{minimum}-#{maximum})"
    end

    def relative_output_argument
      prefix = "#{PROJECT_ROOT}#{File::SEPARATOR}"
      return Shellwords.escape(@configuration.output.delete_prefix(prefix)) if @configuration.output.start_with?(prefix)

      '"${DVR_BENCHMARK_OUTPUT:?Set DVR_BENCHMARK_OUTPUT to the evidence output directory}"'
    end

    def refuse_unsafe_output!(path)
      expanded = File.expand_path(path)
      forbidden = [File::SEPARATOR, PROJECT_ROOT, File.expand_path("~")].uniq
      if forbidden.include?(expanded) || File.exist?(File.join(expanded, ".git"))
        raise EvidenceError, "refusing to replace unsafe output path: #{expanded}"
      end
    end
  end

  module_function

  def project_version
    version_file = File.join(Suite::PROJECT_ROOT, "lib/dry/validation/rust/version.rb")
    match = File.read(version_file).match(/VERSION\s*=\s*"([^"]+)"/)
    raise EvidenceError, "could not read the project version from #{version_file}" unless match

    match[1]
  end
end
