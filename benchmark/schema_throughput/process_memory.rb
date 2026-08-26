# frozen_string_literal: true

require 'open3'

module SchemaThroughput
  # Reads whole-process resident-memory metrics without pretending that Ruby
  # allocation counters describe native/Rust allocation traffic.
  module ProcessMemory
    module_function

    LINUX_STATUS_KEYS = {
      'VmRSS' => 'rss_kb',
      'VmHWM' => 'peak_rss_kb',
      'VmSize' => 'virtual_kb',
      'VmData' => 'data_kb',
      'VmSwap' => 'swap_kb'
    }.freeze
    PRIVATE_KEYS = %w[Private_Clean Private_Dirty Private_Hugetlb].freeze
    DELTA_KEYS = %w[rss_kb pss_kb uss_kb swap_kb data_kb].freeze

    def snapshot(pid: Process.pid)
      linux_snapshot(pid) || portable_snapshot(pid)
    end

    def measurement(before:, after:)
      peak_before = before['peak_rss_kb']
      peak_after = after['peak_rss_kb']
      peak_growth = ([peak_after - peak_before, 0].max if peak_before && peak_after)

      {
        'before' => before,
        'after' => after,
        'delta_kb' => DELTA_KEYS.to_h do |key|
          [key, numeric_delta(before[key], after[key])]
        end.compact,
        'peak_rss_kb' => peak_after,
        'peak_rss_growth_kb' => peak_growth
      }.compact
    end

    def linux_snapshot(pid)
      status_path = "/proc/#{pid}/status"
      return unless File.file?(status_path)

      status = parse_kb_file(status_path)
      smaps = parse_kb_file("/proc/#{pid}/smaps_rollup")
      private_values = PRIVATE_KEYS.filter_map { |key| smaps[key] }

      result = LINUX_STATUS_KEYS.each_with_object({}) do |(source, target), values|
        values[target] = status[source] if status.key?(source)
      end
      result['pss_kb'] = smaps['Pss'] if smaps.key?('Pss')
      result['uss_kb'] = private_values.sum unless private_values.empty?
      result['swap_kb'] ||= smaps['Swap'] if smaps.key?('Swap')
      result
    rescue SystemCallError
      nil
    end
    private_class_method :linux_snapshot

    def portable_snapshot(pid)
      rss = current_rss_kb(pid)
      rss ? { 'rss_kb' => rss } : {}
    end
    private_class_method :portable_snapshot

    def parse_kb_file(path)
      return {} unless File.file?(path)

      File.foreach(path).each_with_object({}) do |line, values|
        match = line.match(/\A([^:]+):\s+(\d+)\s+kB\s*\z/)
        values[match[1]] = match[2].to_i if match
      end
    end
    private_class_method :parse_kb_file

    def current_rss_kb(pid)
      output, status = Open3.capture2e('ps', '-o', 'rss=', '-p', pid.to_s)
      return unless status.success?

      Integer(output.strip)
    rescue Errno::ENOENT, ArgumentError
      nil
    end
    private_class_method :current_rss_kb

    def numeric_delta(before, after)
      return unless before && after

      after - before
    end
    private_class_method :numeric_delta
  end
end
