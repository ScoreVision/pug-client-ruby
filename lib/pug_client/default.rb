# frozen_string_literal: true

module PugClient
  # Default configuration for production environment
  #
  # Provides default values for API endpoints, authentication settings,
  # and connection options when using the production environment.
  module DefaultProduction
    # Production API base URL
    API_ENDPOINT = 'https://api.video.scorevision.com'

    # OAuth2 audience identifier for production
    AUTH_AUDIENCE = 'https://api.fantag.io/'

    # Auth0 OAuth2 token endpoint for production
    AUTH_ENDPOINT = 'https://fantagio.auth0.com/oauth/token'

    # OAuth2 grant type (client credentials flow)
    AUTH_GRANT_TYPE = 'client_credentials'

    # Default page size for pagination
    PER_PAGE = 10

    # Auto-pagination disabled by default
    AUTO_PAGINATE = false

    # Default Faraday connection options
    CONNECTION_OPTIONS = {
      request: {
        open_timeout: 5,
        timeout: 10
      }
    }.freeze

    class << self
      # Get all default options as a hash
      #
      # @return [Hash] All configuration options and their default values
      def options
        Hash[PugClient::Configurable.keys.map { |key| [key, send(key)] }]
      end

      # Get default API endpoint
      # @return [String]
      def api_endpoint
        API_ENDPOINT
      end

      # Get OAuth2 client ID from environment variable
      # @return [String, nil]
      def client_id
        ENV['PUG_CLIENT_ID']
      end

      # Get OAuth2 client secret from environment variable
      # @return [String, nil]
      def client_secret
        ENV['PUG_CLIENT_SECRET']
      end

      # Get default connection options
      # @return [Hash]
      def connection_options
        CONNECTION_OPTIONS
      end

      # Get default page size
      # @return [Integer]
      def per_page
        PER_PAGE
      end

      # Get default auto-pagination setting
      # @return [Boolean]
      def auto_paginate
        AUTO_PAGINATE
      end

      # Get Auth0 token endpoint
      # @return [String]
      def auth_endpoint
        AUTH_ENDPOINT
      end

      # Get OAuth2 audience identifier
      # @return [String]
      def auth_audience
        AUTH_AUDIENCE
      end

      # Get OAuth2 grant type
      # @return [String]
      def auth_grant_type
        AUTH_GRANT_TYPE
      end

      # Get default namespace from environment variable
      # @return [String, nil]
      def namespace
        ENV['PUG_NAMESPACE']
      end
    end
  end

  # Default configuration for staging environment
  #
  # Provides default values for API endpoints, authentication settings,
  # and connection options when using the staging environment.
  module DefaultStaging
    # Staging API base URL
    API_ENDPOINT = 'https://staging-api.video.scorevision.com'

    # OAuth2 audience identifier for staging
    AUTH_AUDIENCE = 'https://staging-api.fantag.io/'

    # Auth0 OAuth2 token endpoint for staging
    AUTH_ENDPOINT = 'https://fantagio-staging.auth0.com/oauth/token'

    # OAuth2 grant type (client credentials flow)
    AUTH_GRANT_TYPE = 'client_credentials'

    # Default page size for pagination
    PER_PAGE = 10

    # Auto-pagination disabled by default
    AUTO_PAGINATE = false

    # Default Faraday connection options
    CONNECTION_OPTIONS = {
      request: {
        open_timeout: 5,
        timeout: 10
      }
    }.freeze

    class << self
      # Get all default options as a hash
      #
      # @return [Hash] All configuration options and their default values
      def options
        Hash[PugClient::Configurable.keys.map { |key| [key, send(key)] }]
      end

      # Get default API endpoint
      # @return [String]
      def api_endpoint
        API_ENDPOINT
      end

      # Get OAuth2 client ID from environment variable
      # @return [String, nil]
      def client_id
        ENV['PUG_CLIENT_ID']
      end

      # Get OAuth2 client secret from environment variable
      # @return [String, nil]
      def client_secret
        ENV['PUG_CLIENT_SECRET']
      end

      # Get default connection options
      # @return [Hash]
      def connection_options
        CONNECTION_OPTIONS
      end

      # Get default page size
      # @return [Integer]
      def per_page
        PER_PAGE
      end

      # Get default auto-pagination setting
      # @return [Boolean]
      def auto_paginate
        AUTO_PAGINATE
      end

      # Get Auth0 token endpoint
      # @return [String]
      def auth_endpoint
        AUTH_ENDPOINT
      end

      # Get OAuth2 audience identifier
      # @return [String]
      def auth_audience
        AUTH_AUDIENCE
      end

      # Get OAuth2 grant type
      # @return [String]
      def auth_grant_type
        AUTH_GRANT_TYPE
      end

      # Get default namespace from environment variable
      # @return [String, nil]
      def namespace
        ENV['PUG_NAMESPACE']
      end
    end
  end
end
