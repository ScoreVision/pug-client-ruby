# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

# Default task runs tests
task default: :spec

# RSpec task
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--format documentation --color'
end

# RuboCop task
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

desc 'Run all checks (tests and linting)'
task check: %i[spec rubocop]

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].execute
end

# YARD documentation task
YARD::Rake::YardocTask.new(:docs) do |t|
  t.files = ['lib/**/*.rb']
  t.options = ['--output-dir=doc', '--readme=README.md', '--markup=markdown', '--no-private']
end

desc 'Open documentation index'
task doc: :docs do
  system 'open doc/index.html'
end
