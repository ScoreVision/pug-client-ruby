# frozen_string_literal: true

require_relative 'lib/pug_client/version'

Gem::Specification.new do |spec|
  spec.name       = 'pug-client'
  spec.version    = PugClient::VERSION
  spec.authors    = ['Zach Norris']
  spec.email      = ['zach.norris@scorevision.com']

  spec.summary    = 'A ruby client for Pug video API service.'
  spec.description = 'Ruby client library for the Pug Video API. Provides a simple, intuitive interface for managing video resources, livestreams, campaigns, and more. Modeled after Octokit.rb with support for automatic pagination, configurable environments, and Auth0 authentication.'
  spec.homepage   = 'http://git.scorevision.com/fantag/pug-client-ruby'
  spec.license    = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata = {
    'source_code_uri' => 'http://git.scorevision.com/fantag/pug-client-ruby',
    'bug_tracker_uri' => 'http://git.scorevision.com/fantag/pug-client-ruby/issues',
    'changelog_uri' => 'http://git.scorevision.com/fantag/pug-client-ruby/blob/main/CHANGELOG.md'
  }

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '>= 2.14', '< 3'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'redcarpet', '~> 3.6'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.6'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'solargraph'
  spec.add_development_dependency 'vcr', '~> 6.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'yard', '~> 0.9'
end
