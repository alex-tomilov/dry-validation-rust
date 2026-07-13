# frozen_string_literal: true

require "rake/testtask"
require "rubygems/package_task"

EXTENSION_DIR = File.expand_path("ext/dry_validation_rust", __dir__)

desc "Compile the Rust extension"
task :compile do
  Dir.chdir(EXTENSION_DIR) do
    ruby "extconf.rb" if !File.exist?("Makefile") || File.mtime("extconf.rb") > File.mtime("Makefile")
    sh "make"
  end
end

Rake::TestTask.new(:test => :compile) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

spec = Gem::Specification.load(File.expand_path("dry-validation-rust.gemspec", __dir__))
Gem::PackageTask.new(spec)

task default: :test
