# frozen_string_literal: true

require "fileutils"
require "rake/testtask"
require "rubygems/package_task"
require "stringio"
require "tmpdir"
require "zlib"

EXTENSION_DIR = File.expand_path("ext/dry_validation_rust", __dir__)
GEMSPEC_PATH = File.expand_path("dry-validation-rust.gemspec", __dir__)
PACKAGE_REQUIRED_FILES = %w[
  CHANGELOG.md
  LICENSE
  NOTICE.md
  README.md
  docs/ARCHITECTURE.md
  docs/COMPATIBILITY.md
  docs/FEASIBILITY.md
  docs/SUPPORT_MATRIX.md
  docs/VERIFICATION.md
  ext/dry_validation_rust/Cargo.lock
  ext/dry_validation_rust/Cargo.toml
  ext/dry_validation_rust/extconf.rb
  ext/dry_validation_rust/src/lib.rs
  lib/dry/validation/rust.rb
  lib/dry/validation/rust/contract.rb
  lib/dry/validation/rust/native.rb
  lib/dry/validation/rust/version.rb
  rust-toolchain.toml
].freeze
PACKAGE_FORBIDDEN_PATTERNS = {
  "secret or credential files" => %r{(^|/)(?:\.env(?:\.|$)|.*\.(?:pem|key|p12|pfx)|id_(?:rsa|dsa|ed25519)|master\.key|credentials\.ya?ml\.enc)\z}i,
  "local build artifacts" => %r{\A(?:pkg|coverage|\.bundle|\.ruby-lsp)/|\Aext/dry_validation_rust/(?:target/|Makefile\z|mkmf\.log\z|native\.)|(?:\.gem|\.o|\.so|\.bundle|\.dylib|\.dll|\.log)\z},
  "editor files" => %r{(^|/)(?:\.DS_Store|.*~|#.*#|\.#.*|.*\.sw[op])\z|(^|/)\.(?:idea|vscode)/},
  "non-runtime project material" => %r{\A(?:benchmark|examples|docs/codex)/}
}.freeze

def package_file_list(gem_path)
  data_tar_gz = nil

  File.open(gem_path, "rb") do |file|
    Gem::Package::TarReader.new(file) do |gem_tar|
      gem_tar.each do |entry|
        data_tar_gz = entry.read if entry.full_name == "data.tar.gz"
      end
    end
  end

  raise "Gem data archive missing from #{gem_path}" unless data_tar_gz

  files = []
  Zlib::GzipReader.wrap(StringIO.new(data_tar_gz)) do |gzip|
    Gem::Package::TarReader.new(gzip) do |data_tar|
      data_tar.each do |entry|
        files << entry.full_name unless entry.directory?
      end
    end
  end
  files.sort
end

def validate_package_files(gem_path, expected_files)
  files = package_file_list(gem_path)

  puts "Package contents:"
  puts files.map { |path| "  #{path}" }

  missing = PACKAGE_REQUIRED_FILES - files
  raise "Package is missing required files: #{missing.join(", ")}" unless missing.empty?

  unexpected = files - expected_files
  raise "Package contains files outside spec.files: #{unexpected.join(", ")}" unless unexpected.empty?

  omitted = expected_files - files
  raise "Package omitted spec.files entries: #{omitted.join(", ")}" unless omitted.empty?

  PACKAGE_FORBIDDEN_PATTERNS.each do |label, pattern|
    matches = files.grep(pattern)
    raise "Package contains #{label}: #{matches.join(", ")}" unless matches.empty?
  end

  native_sources = files.grep(%r{\Aext/dry_validation_rust/src/.*\.rs\z})
  raise "Package is missing native Rust source files" if native_sources.empty?

  files
end

def with_unbundled_environment(&block)
  if defined?(Bundler)
    Bundler.with_unbundled_env(&block)
  else
    yield
  end
end

def rb_sys_gem_lib_path
  File.join(Gem::Specification.find_by_name("rb_sys").full_gem_path, "lib")
end

def smoke_installed_package(gem_path)
  ruby_code = <<~'RUBY'
    gem "dry-validation-rust"
    require "dry/validation/rust"

    loaded = Gem.loaded_specs.fetch("dry-validation-rust")
    gem_home = ENV.fetch("GEM_HOME")
    loaded_path = File.realpath(loaded.full_gem_path)
    expected_path = File.realpath(gem_home)
    loaded_from_gem_home = loaded_path == expected_path || loaded_path.start_with?("#{expected_path}#{File::SEPARATOR}")
    abort "loaded gem from #{loaded_path}, expected #{expected_path}" unless loaded_from_gem_home
    abort "loaded upstream dry-validation" if Gem.loaded_specs.key?("dry-validation")

    contract = Class.new(Dry::Validation::Rust::Contract) do
      params do
        required(:age).value(:integer)
        required(:name).filled(:string)
      end

      rule(:age) do
        key.failure("must be an adult") if value < 18
      end
    end

    success = contract.new.call("age" => "21", "name" => "Jane")
    abort success.errors.to_h.inspect unless success.success? && success.to_h == {age: 21, name: "Jane"}

    failure = contract.new.call("age" => "17", "name" => "Jane")
    abort failure.errors.to_h.inspect unless failure.failure? && failure.errors.to_h == {age: ["must be an adult"]}
  RUBY

  Dir.mktmpdir("dry-validation-rust-gem-home") do |gem_home|
    Dir.mktmpdir("dry-validation-rust-package-smoke") do |workdir|
      env = {
        "GEM_HOME" => gem_home,
        "GEM_PATH" => ([gem_home] + Gem.path).uniq.join(File::PATH_SEPARATOR),
        "RB_SYS_GEM_LIB" => rb_sys_gem_lib_path
      }

      with_unbundled_environment do
        sh env, "gem", "install", "--local", gem_path, "--no-document"
        Dir.chdir(workdir) do
          sh env, "ruby", "-e", ruby_code
        end
      end
    end
  end
end

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

spec = Gem::Specification.load(GEMSPEC_PATH)
Gem::PackageTask.new(spec)

namespace :package do
  desc "Build and audit the source gem package"
  task :audit do
    FileUtils.mkdir_p(File.expand_path("pkg", __dir__))
    gem_path = File.expand_path("pkg/#{spec.full_name}.gem", __dir__)

    sh "gem", "build", GEMSPEC_PATH, "--output", gem_path
    validate_package_files(gem_path, spec.files.sort)
    smoke_installed_package(gem_path)
  end
end

task default: :test
