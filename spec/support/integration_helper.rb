# frozen_string_literal: true

# Integration test helper for testing against the live Pug Video API
#
# This helper provides utilities for integration tests that record real API
# interactions using VCR. These tests validate the client against specific
# API versions.
#
# Setup:
#   1. Ensure credentials are configured in example/env.sh
#   2. Load environment: source example/env.sh
#   3. Run integration tests: bundle exec rspec spec/integration --tag integration
#
# Environment Variables:
#   - PUG_CLIENT_ID: OAuth2 client ID (required for recording, optional for playback)
#   - PUG_CLIENT_SECRET: OAuth2 client secret (required for recording, optional for playback)
#   - PUG_NAMESPACE: Default namespace (required for recording, optional for playback)
#
# Note: When running tests with existing VCR cassettes, all environment variables are
# optional. The namespace is read from the .namespace file in the cassette directory,
# and placeholder credentials are used since VCR replays recorded HTTP interactions.
# When recording new cassettes, all three environment variables must be set.

module IntegrationHelper
  # Get the path to the namespace file for the current API version
  #
  # @return [String] Path to the .namespace file
  def namespace_file_path
    api_version = ENV['API_VERSION'] || PugClient::API_VERSION
    File.join('spec', 'cassettes', "api_v#{api_version}", '.namespace')
  end

  # Read namespace from the cassette directory file
  #
  # @return [String, nil] Namespace ID or nil if file doesn't exist
  def read_namespace_from_file
    path = namespace_file_path
    return nil unless File.exist?(path)

    File.read(path).strip
  end

  # Write namespace to the cassette directory file
  #
  # @param namespace [String] Namespace ID to store
  def write_namespace_to_file(namespace)
    path = namespace_file_path
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, namespace)
  end

  # Check if cassettes exist for the current API version
  #
  # @return [Boolean] True if cassette directory exists and has recordings
  def cassettes_exist?
    path = namespace_file_path
    cassette_dir = File.dirname(path)
    File.directory?(cassette_dir) && !Dir.glob(File.join(cassette_dir, '**', '*.yml')).empty?
  end

  # Create a configured client for integration testing
  #
  # The client reads credentials from environment variables or uses placeholders
  # when VCR cassettes exist. When running with existing cassettes, no credentials
  # are needed because VCR replays recorded HTTP interactions.
  #
  # @return [PugClient::Client] Configured client instance
  # @raise [RuntimeError] If required environment variables are not set for recording
  def create_test_client
    # Check if we have cassettes (playback mode) or need to record
    has_cassettes = cassettes_exist?

    # Get credentials (use VCR filter values for playback, require real values for recording)
    if has_cassettes && !ENV['PUG_CLIENT_ID']
      # Set ENV to VCR placeholder values so request bodies match recorded cassettes
      # VCR's filter_sensitive_data will replace these with <PUG_CLIENT_ID>, etc.
      ENV['PUG_CLIENT_ID'] = 'vcr-placeholder-client-id'
      ENV['PUG_CLIENT_SECRET'] = 'vcr-placeholder-client-secret'
    elsif !has_cassettes
      # Recording new cassettes - require real credentials
      auth_vars = %w[PUG_CLIENT_ID PUG_CLIENT_SECRET]
      missing_auth = auth_vars.reject { |var| ENV[var] }

      unless missing_auth.empty?
        raise "Missing required authentication variables for recording: #{missing_auth.join(', ')}. " \
              'Set these to record new cassettes.'
      end
    end

    # For namespace, try: ENV var → cassette file → error
    namespace = ENV['PUG_NAMESPACE'] || read_namespace_from_file

    if namespace.nil?
      raise 'Missing PUG_NAMESPACE environment variable and no recorded namespace found. ' \
            'Set PUG_NAMESPACE to record new cassettes.'
    end

    # Store namespace for future test runs if from ENV (recording scenario)
    if ENV['PUG_NAMESPACE']
      write_namespace_to_file(namespace)
    else
      # Set ENV var from file so tests can access it via ENV['PUG_NAMESPACE']
      ENV['PUG_NAMESPACE'] = namespace
    end

    PugClient::Client.new(
      environment: :staging,
      client_id: ENV['PUG_CLIENT_ID'],
      client_secret: ENV['PUG_CLIENT_SECRET'],
      namespace: namespace
    )
  end

  # Get the API version being tested
  #
  # @return [String] API version (e.g., '0.3.0')
  def api_version
    PugClient::API_VERSION
  end

  # Note on Test Data:
  # Integration tests should use **static, descriptive test data** rather than
  # dynamic timestamps. VCR cassettes are isolated by test name, so there's no
  # risk of collision. Static data makes cassettes human-readable and ensures
  # test expectations match cassette responses during playback.
  #
  # Example:
  #   slug = 'test-campaign-slug'         # Good - static, readable
  #   url = 'https://test.example.com'    # Good - deterministic
  #   value = "updated-#{Time.now.to_i}"  # Bad - causes VCR mismatches
end

# Configure RSpec for integration tests
RSpec.configure do |config|
  config.include IntegrationHelper, :integration

  # Allow real HTTP connections for integration tests
  config.before(:each, :integration) do
    WebMock.allow_net_connect!
  end

  # Re-enable WebMock restrictions after integration tests
  config.after(:each, :integration) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
