# frozen_string_literal: true

module PugClient
  module Resources
    # NamespaceClient resource represents namespace-scoped authentication credentials
    #
    # @note **This resource is intentionally not supported by this Ruby client.**
    #   While the API provides endpoints for creating namespace-scoped credentials,
    #   this functionality is excluded from the Ruby client for security and
    #   architectural reasons.
    #
    # NamespaceClients provide authentication credentials that are scoped to a
    # specific namespace, allowing delegated access to resources within that namespace.
    #
    # To create namespace credentials, please use the web console or contact your
    # administrator.
    #
    # @see FeatureNotSupportedError
    class NamespaceClient < Resource
      # Attributes that cannot be modified after creation
      #
      # Note: Since this resource is immutable, all attributes are effectively read-only.
      # The secret attribute is particularly sensitive - it's only returned once during creation.
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
        secret
      ].freeze

      attr_reader :namespace_id

      # Initialize a new NamespaceClient resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this client belongs to
      # @param attributes [Hash] NamespaceClient attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Create a new namespace client credential
      #
      # @note This endpoint is intentionally not supported by this Ruby client.
      #   Namespace client creation is excluded for security and architectural reasons.
      #   Please use the web console or contact your administrator to create
      #   namespace-scoped credentials.
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Optional attributes
      # @return [void]
      # @raise [FeatureNotSupportedError] Always raised - this feature is not supported
      #
      # @example Attempting to create a namespace client
      #   NamespaceClient.create(client, 'my-namespace')
      #   # => raises FeatureNotSupportedError
      def self.create(_client, _namespace_id, _options = {})
        raise FeatureNotSupportedError.new(
          'Namespace client creation',
          'This endpoint is intentionally excluded from the Ruby client. ' \
          'Please use the web console or contact your administrator to create namespace credentials.'
        )
      end

      # Instantiate a namespace client from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [NamespaceClient] The namespace client resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:_namespace_id]
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the namespace client
      #
      # @raise [NotImplementedError] NamespaceClients are immutable and cannot be updated
      def save
        raise NotImplementedError,
              'NamespaceClients cannot be updated after creation. They are immutable.'
      end

      # Reload the namespace client from the API
      #
      # @raise [NotImplementedError] The API does not provide an endpoint to retrieve namespace clients
      def reload
        raise NotImplementedError,
              'NamespaceClients cannot be retrieved after creation. ' \
              'The API does not provide a read endpoint for security reasons.'
      end

      # Delete the namespace client
      #
      # @raise [NotImplementedError] The API does not provide an endpoint to delete namespace clients
      def delete
        raise NotImplementedError,
              'NamespaceClients cannot be deleted via the API. ' \
              'Please use the web console or contact support to revoke credentials.'
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this client belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Check if the secret is still available
      #
      # The secret is only available immediately after creation. Once the object
      # is serialized or the application restarts, the secret will no longer be accessible.
      #
      # @return [Boolean] true if secret is available
      def secret_available?
        !@current_attributes[:secret].nil?
      end

      # Human-readable representation of the namespace client
      #
      # @return [String]
      def inspect
        secret_info = secret_available? ? 'secret=<available>' : 'secret=<unavailable>'
        "#<#{self.class.name} id=#{id.inspect} #{secret_info} namespace_id=#{@namespace_id.inspect}>"
      end
    end
  end
end
