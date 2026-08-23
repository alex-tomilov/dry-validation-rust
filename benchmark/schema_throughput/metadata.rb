# frozen_string_literal: true

require 'etc'
require 'open3'
require 'rbconfig'
require 'time'

module SchemaThroughput
  module Metadata
    module_function

    def snapshot(project_root:)
      {
        'recorded_at' => Time.now.utc.iso8601,
        'git_sha' => git(project_root, 'rev-parse', 'HEAD'),
        'git_short_sha' => git(project_root, 'rev-parse', '--short=12', 'HEAD'),
        'git_branch' => git(project_root, 'rev-parse', '--abbrev-ref', 'HEAD'),
        'git_dirty' => git_dirty?(project_root),
        'ruby' => RUBY_DESCRIPTION,
        'ruby_engine' => defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby',
        'ruby_platform' => RUBY_PLATFORM,
        'yjit_enabled' => yjit_enabled?,
        'host_os' => RbConfig::CONFIG['host_os'],
        'kernel' => command('uname', '-srvm'),
        'host_cpu' => RbConfig::CONFIG['host_cpu'],
        'cpu_model' => cpu_model,
        'logical_cpus' => Etc.nprocessors,
        'cpu_governor' => cpu_governor,
        'rustc' => command('rustc', '--version'),
        'cargo' => command('cargo', '--version')
      }
    end

    def git_dirty?(project_root)
      output = git(project_root, 'status', '--porcelain')
      output.nil? ? false : !output.empty?
    end
    private_class_method :git_dirty?

    def git(project_root, *)
      command('git', '-C', project_root, *)
    end
    private_class_method :git

    def command(*command)
      output, status = Open3.capture2e(*command)
      return output.strip if status.success?

      nil
    rescue Errno::ENOENT
      nil
    end
    private_class_method :command

    def yjit_enabled?
      defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : false
    end
    private_class_method :yjit_enabled?

    def cpu_model
      linux_cpu_model || mac_cpu_model || ENV.fetch('PROCESSOR_IDENTIFIER', nil)
    end
    private_class_method :cpu_model

    def cpu_governor
      path = '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'
      File.file?(path) ? File.read(path).strip : nil
    rescue SystemCallError
      nil
    end
    private_class_method :cpu_governor

    def linux_cpu_model
      return unless File.file?('/proc/cpuinfo')

      line = File.foreach('/proc/cpuinfo').find { |entry| entry.start_with?('model name') }
      return unless line

      line.split(':', 2).last.strip
    end
    private_class_method :linux_cpu_model

    def mac_cpu_model
      return unless RbConfig::CONFIG['host_os'].include?('darwin')

      command('sysctl', '-n', 'machdep.cpu.brand_string') || command('sysctl', '-n', 'hw.model')
    end
    private_class_method :mac_cpu_model
  end
end
