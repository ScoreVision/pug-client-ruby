# frozen_string_literal: true

module PugClient
  # Configuration options for PugClient
  #
  # Provides configuration attributes for both module-level and instance-level
  # client configuration. Configuration follows a layered approach with clear
  # precedence: environment defaults < module-level config < instance options.
  #
  # @example Configure module-level settings
  #   PugClient.configure do |c|
  #     c.client_id = ENV['PUG_CLIENT_ID']
  #     c.client_secret = ENV['PUG_CLIENT_SECRET']
  #     c.per_page = 50
  #     c.auto_paginate = true
  #   end
  #
  # @example Access configuration values
  #   PugClient.api_endpoint  # => "https://api.video.scorevision.com"
  #   PugClient.per_page      # => 50
  module Configurable
    # @!attribute [rw] api_endpoint
    #   @return [String] Base URL for the Pug Video API
    # @!attribute [rw] namespace
    #   @return [String] Default namespace for all resource operations (required)
    # @!attribute [rw] client_id
    #   @return [String] OAuth2 client ID for authentication
    # @!attribute [rw] client_secret
    #   @return [String] OAuth2 client secret for authentication
    # @!attribute [rw] connection_options
    #   @return [Hash] Faraday connection options (timeouts, etc.)
    # @!attribute [rw] per_page
    #   @return [Integer] Default number of results per page (default: 10)
    # @!attribute [rw] auto_paginate
    #   @return [Boolean] Automatically paginate through all results
    # @!attribute [rw] auth_endpoint
    #   @return [String] Auth0 OAuth2 token endpoint URL
    # @!attribute [rw] auth_audience
    #   @return [String] OAuth2 audience identifier
    # @!attribute [rw] auth_grant_type
    #   @return [String] OAuth2 grant type (default: 'client_credentials')
    # @!attribute [rw] access_token
    #   @return [String] OAuth2 access token (managed by Authentication module, not configurable)
    attr_accessor :api_endpoint, :namespace, :client_id, :client_secret,
                  :connection_options,
                  :per_page, :auto_paginate,
                  :auth_endpoint, :auth_audience, :auth_grant_type,
                  :access_token

    # List of all configurable keys
    #
    # @return [Array<Symbol>] Array of configuration key symbols
    def self.keys
      @keys ||= %i[
        api_endpoint
        namespace
        client_id
        client_secret
        connection_options
        per_page
        auto_paginate
        auth_endpoint
        auth_audience
        auth_grant_type
      ]
    end

    # Configure client options using a block
    #
    # @yield [self] Yields the current object for configuration
    # @return [void]
    # @example
    #   PugClient.configure do |c|
    #     c.client_id = 'my_client_id'
    #     c.per_page = 25
    #   end
    def configure
      yield self
    end
  end
end
