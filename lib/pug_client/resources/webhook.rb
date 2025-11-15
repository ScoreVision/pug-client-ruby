# frozen_string_literal: true

module PugClient
  module Resources
    # Webhook resource represents an event notification endpoint within a namespace
    #
    # Webhooks provide event notifications for resource lifecycle changes
    # such as video ready, livestream published, etc.
    class Webhook < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
      ].freeze

      attr_reader :namespace_id

      # Initialize a new Webhook resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this webhook belongs to
      # @param attributes [Hash] Webhook attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find a webhook by ID
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param webhook_id [String] The webhook ID
      # @param options [Hash] Additional options
      # @return [Webhook] The webhook resource
      # @raise [ResourceNotFound] If the webhook doesn't exist
      # @raise [NetworkError] If the API request fails
      def self.find(client, namespace_id, webhook_id, options = {})
        response = client.get("namespaces/#{namespace_id}/webhooks/#{webhook_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        # Treat both 404 and 422 (invalid ID format) as ResourceNotFound
        if e.is_a?(Faraday::ResourceNotFound) || (e.respond_to?(:response) && [404, 422].include?(e.response&.status))
          raise ResourceNotFound.new('Webhook', webhook_id)
        end

        raise NetworkError, e.message
      end

      # Get all webhooks in a namespace
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Additional options for filtering/pagination
      # @return [ResourceEnumerator] Enumerator for lazy loading webhooks
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          base_url: "namespaces/#{namespace_id}/webhooks",
          resource_class: self,
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create a new webhook
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param url [String] Webhook endpoint URL
      # @param actions [Array<String>] Event actions to trigger webhook
      # @param options [Hash] Optional attributes (metadata)
      # @return [Webhook] The created webhook resource
      # @raise [NetworkError] If the API request fails
      # @example
      #   Webhook.create(client, 'my-namespace',
      #     'https://my.endpoint.com/webhooks',
      #     ['video.ready', 'livestream.published']
      #   )
      def self.create(client, namespace_id, url, actions, options = {})
        # Convert to API format (camelCase)
        attributes = AttributeTranslator.to_api(options)
        attributes[:url] = url
        attributes[:actions] = actions

        body = {
          data: {
            type: 'webhooks',
            attributes: attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/webhooks", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate a webhook from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [Webhook] The webhook resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the webhook
      #
      # Uses JSON Patch (RFC 6902) to send only changed attributes.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] If the API request fails
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/webhooks/#{id}", { data: operations })

        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload the webhook from the API
      #
      # Discards any unsaved changes.
      #
      # @return [self]
      # @raise [NetworkError] If the API request fails
      def reload
        response = @client.get("namespaces/#{@namespace_id}/webhooks/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete the webhook
      #
      # After deletion, the resource is frozen and cannot be modified.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] If the API request fails
      def delete
        @client.delete("namespaces/#{@namespace_id}/webhooks/#{id}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this webhook belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Get the webhook URL
      #
      # @return [String] The webhook endpoint URL
      def url
        @current_attributes[:url]
      end

      # Get the webhook actions
      #
      # @return [Array<String>] Array of event action names
      def actions
        @current_attributes[:actions] || []
      end

      # Human-readable representation of the webhook
      #
      # @return [String]
      def inspect
        url_display = url ? url[0..50] : 'nil'
        url_display += '...' if url && url.length > 50
        actions_count = actions.size
        "#<#{self.class.name} id=#{id.inspect} url=#{url_display.inspect} actions=#{actions_count} changed=#{changed?}>"
      end
    end
  end
end
