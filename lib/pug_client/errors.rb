# frozen_string_literal: true

module PugClient
  # Base error class for all PugClient errors
  class Error < StandardError; end

  # Raised when authentication fails
  class AuthenticationError < Error; end

  # Raised when a resource cannot be found (404)
  class ResourceNotFound < Error
    attr_reader :resource_type, :id

    def initialize(resource_type, id)
      @resource_type = resource_type
      @id = id
      super("#{resource_type} not found: #{id}")
    end
  end

  # Raised when a validation error occurs
  class ValidationError < Error; end

  # Raised when a network error occurs
  class NetworkError < Error; end

  # Raised when an operation times out
  class TimeoutError < Error; end

  # Raised when attempting to modify a frozen resource
  class ResourceFrozenError < Error; end

  # Raised when a feature is intentionally not supported by this client
  #
  # Some API endpoints exist but are intentionally excluded from this Ruby client
  # for architectural or security reasons. This error provides clear feedback when
  # attempting to use these excluded features.
  #
  # @example
  #   begin
  #     client.create_namespace_client
  #   rescue PugClient::FeatureNotSupportedError => e
  #     puts e.message
  #     # => "Namespace client creation is not supported by this client: ..."
  #   end
  class FeatureNotSupportedError < Error
    # Create a new FeatureNotSupportedError
    #
    # @param feature [String] The name of the unsupported feature
    # @param reason [String, nil] Optional explanation for why it's not supported
    def initialize(feature, reason = nil)
      message = "#{feature} is not supported by this client"
      message += ": #{reason}" if reason
      super(message)
    end
  end
end
