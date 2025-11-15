# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  # Use versioned cassette directories to support testing against multiple API versions
  # Default to current API version, but allow override via environment variable
  api_version = ENV['API_VERSION'] || PugClient::API_VERSION
  config.cassette_library_dir = "spec/cassettes/api_v#{api_version}"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data('<PUG_CLIENT_ID>') { ENV['PUG_CLIENT_ID'] }
  config.filter_sensitive_data('<PUG_CLIENT_SECRET>') { ENV['PUG_CLIENT_SECRET'] }
  config.filter_sensitive_data('<PUG_ACCESS_TOKEN>') { ENV['PUG_ACCESS_TOKEN'] }

  # Filter access tokens from responses
  config.filter_sensitive_data('<ACCESS_TOKEN>') do |interaction|
    if interaction.response.body.include?('access_token')
      begin
        body = JSON.parse(interaction.response.body)
        body['access_token']
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Filter Authorization headers
  config.filter_sensitive_data('<AUTHORIZATION>') do |interaction|
    interaction.request.headers['Authorization']&.first
  end

  # Default record mode - change to :new_episodes when recording real API calls
  # Match on method and URI only (not body) to allow dynamic data like timestamps
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri]
  }

  # Allow localhost connections (for local development)
  config.ignore_localhost = true
end
