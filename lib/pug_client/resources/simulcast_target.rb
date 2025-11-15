# frozen_string_literal: true

module PugClient
  module Resources
    # SimulcastTarget resource represents an external RTMP destination for livestreams
    #
    # SimulcastTargets define external RTMP URLs to forward livestreams to,
    # enabling multi-platform streaming (YouTube, Facebook, Twitch, etc.)
    class SimulcastTarget < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
      ].freeze

      attr_reader :namespace_id

      # Initialize a new SimulcastTarget resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this simulcast target belongs to
      # @param attributes [Hash] SimulcastTarget attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find a simulcast target by ID
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param target_id [String] The simulcast target ID
      # @param options [Hash] Additional options
      # @return [SimulcastTarget] The simulcast target resource
      # @raise [ResourceNotFound] If the simulcast target doesn't exist
      # @raise [NetworkError] If the API request fails
      def self.find(client, namespace_id, target_id, options = {})
        response = client.get("namespaces/#{namespace_id}/simulcasttargets/#{target_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        # Treat both 404 and 422 (invalid ID format) as ResourceNotFound
        if e.is_a?(Faraday::ResourceNotFound) || (e.respond_to?(:response) && [404, 422].include?(e.response&.status))
          raise ResourceNotFound.new('SimulcastTarget', target_id)
        end

        raise NetworkError, e.message
      end

      # Get all simulcast targets in a namespace
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Additional options for filtering/pagination
      # @return [ResourceEnumerator] Enumerator for lazy loading simulcast targets
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          base_url: "namespaces/#{namespace_id}/simulcasttargets",
          resource_class: self,
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create a new simulcast target
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param url [String] RTMP URL to forward stream to
      # @param options [Hash] Optional attributes (metadata)
      # @return [SimulcastTarget] The created simulcast target resource
      # @raise [NetworkError] If the API request fails
      # @example
      #   SimulcastTarget.create(client, 'my-namespace', 'rtmp://youtube.com/live/streamkey')
      #   SimulcastTarget.create(client, 'my-namespace', 'rtmp://youtube.com/live/streamkey',
      #     metadata: { labels: { platform: 'youtube' } })
      def self.create(client, namespace_id, url, options = {})
        # Convert to API format (camelCase)
        attributes = AttributeTranslator.to_api(options)
        attributes[:url] = url

        body = {
          data: {
            type: 'SimulcastTargets',
            attributes: attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/simulcasttargets", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate a simulcast target from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [SimulcastTarget] The simulcast target resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the simulcast target
      #
      # Uses JSON Patch (RFC 6902) to send only changed attributes.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] If the API request fails
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/simulcasttargets/#{id}", { data: operations })

        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload the simulcast target from the API
      #
      # Discards any unsaved changes.
      #
      # @return [self]
      # @raise [NetworkError] If the API request fails
      def reload
        response = @client.get("namespaces/#{@namespace_id}/simulcasttargets/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete the simulcast target
      #
      # After deletion, the resource is frozen and cannot be modified.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] If the API request fails
      def delete
        @client.delete("namespaces/#{@namespace_id}/simulcasttargets/#{id}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this simulcast target belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Get the RTMP URL
      #
      # @return [String] The RTMP URL
      def url
        @current_attributes[:url]
      end

      # Human-readable representation of the simulcast target
      #
      # @return [String]
      def inspect
        url_display = url ? url[0..50] : 'nil'
        url_display += '...' if url && url.length > 50
        "#<#{self.class.name} id=#{id.inspect} url=#{url_display.inspect} changed=#{changed?}>"
      end
    end
  end
end
