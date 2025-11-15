# frozen_string_literal: true

require 'faraday'

module PugClient
  # Auth0 OAuth2 client credentials authentication
  #
  # This module provides OAuth2 authentication using the client credentials
  # grant flow with Auth0. It handles token fetching, storage, expiration
  # tracking, and automatic token refresh.
  #
  # @example Authenticate and make API calls
  #   client = PugClient::Client.new(
  #     client_id: ENV['PUG_CLIENT_ID'],
  #     client_secret: ENV['PUG_CLIENT_SECRET']
  #   )
  #   client.authenticate!
  #   namespaces = client.namespaces
  #
  # @example Automatic authentication
  #   client.ensure_authenticated!  # Only authenticates if needed
  module Authentication
    # Authenticate using Auth0 client credentials flow
    #
    # Fetches an access token from Auth0 and stores it along with its
    # expiration time. Raises an error if authentication fails.
    #
    # @return [Boolean] true if authentication succeeded
    # @raise [AuthenticationError] if authentication fails
    # @example
    #   client.authenticate!
    #   client.authenticated?  # => true
    def authenticate!
      response = auth_connection.post do |req|
        req.body = {
          client_id: @client_id,
          client_secret: @client_secret,
          audience: @auth_audience,
          grant_type: @auth_grant_type
        }
      end

      unless response.success?
        raise AuthenticationError, "Authentication failed: #{response.status} - #{response.body.inspect}"
      end

      # response.body is already parsed as JSON by Faraday
      token_data = response.body
      @access_token = token_data['access_token']
      @token_expires_at = Time.now + token_data['expires_in'] if token_data['expires_in']
      true
    end

    # Check if client has an access token
    #
    # @return [Boolean] true if an access token is present
    # @example
    #   client.authenticated?  # => false
    #   client.authenticate!
    #   client.authenticated?  # => true
    def authenticated?
      !!@access_token
    end

    # Check if the current access token is expired
    #
    # @return [Boolean] true if token is expired or expiration time is unknown
    # @example
    #   client.authenticate!
    #   client.token_expired?  # => false
    def token_expired?
      return true unless @token_expires_at

      Time.now >= @token_expires_at
    end

    # Ensure client is authenticated, refreshing token if needed
    #
    # Only fetches a new token if the client is not authenticated or
    # the current token has expired.
    #
    # @return [void]
    # @example
    #   client.ensure_authenticated!  # Authenticates if needed
    #   client.ensure_authenticated!  # No-op if already authenticated
    def ensure_authenticated!
      authenticate! if !authenticated? || token_expired?
    end

    private

    # Create or return a cached Faraday connection for auth requests
    #
    # @return [Faraday::Connection] Faraday connection configured for Auth0
    # @api private
    def auth_connection
      @auth_connection ||= Faraday.new(url: @auth_endpoint) do |conn|
        conn.request :json
        conn.response :json
        conn.headers['Content-Type'] = 'application/json'
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
