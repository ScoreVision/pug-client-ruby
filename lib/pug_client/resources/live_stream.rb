# frozen_string_literal: true

module PugClient
  module Resources
    # LiveStream resource represents a live streaming session within a namespace
    #
    # LiveStreams support real-time video streaming with RTMP ingest and
    # playback URLs, simulcast to multiple platforms, and state management.
    class LiveStream < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
        started_at
        stream_status
        stream_urls
        playback_urls
        thumbnails
      ].freeze

      attr_reader :namespace_id

      # Initialize a new LiveStream resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this livestream belongs to
      # @param attributes [Hash] LiveStream attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find a livestream by ID
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param livestream_id [String] The livestream ID
      # @param options [Hash] Additional options
      # @return [LiveStream] The livestream resource
      # @raise [ResourceNotFound] If the livestream doesn't exist
      # @raise [NetworkError] If the API request fails
      def self.find(client, namespace_id, livestream_id, options = {})
        response = client.get("namespaces/#{namespace_id}/livestreams/#{livestream_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        # Treat both 404 and 422 (invalid ID format) as ResourceNotFound
        if e.is_a?(Faraday::ResourceNotFound) || (e.respond_to?(:response) && [404, 422].include?(e.response&.status))
          raise ResourceNotFound.new('LiveStream', livestream_id)
        end

        raise NetworkError, e.message
      end

      # Get all livestreams in a namespace
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Additional options for pagination
      # @return [ResourceEnumerator] Enumerator for lazy loading livestreams
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          base_url: "namespaces/#{namespace_id}/livestreams",
          resource_class: self,
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create a new livestream
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Optional attributes (started_at, metadata, location,
      #   simulcast_targets)
      # @return [LiveStream] The created livestream resource
      # @raise [NetworkError] If the API request fails
      def self.create(client, namespace_id, options = {})
        # Convert Time objects to ISO8601 strings
        options = options.dup
        options[:started_at] = options[:started_at].utc.iso8601 if options[:started_at].is_a?(Time)

        # Extract IDs from SimulcastTarget objects if present
        if options[:simulcast_targets]
          options[:simulcast_targets] = extract_simulcast_target_ids(options[:simulcast_targets])
        end

        # Convert to API format (camelCase)
        attributes = AttributeTranslator.to_api(options)

        body = {
          data: {
            type: 'LiveStreams',
            attributes: attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/livestreams", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate a livestream from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [LiveStream] The livestream resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the livestream
      #
      # Uses JSON Patch (RFC 6902) to send only changed attributes.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] If the API request fails
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/livestreams/#{id}", { data: operations })

        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload the livestream from the API
      #
      # Discards any unsaved changes.
      #
      # @return [self]
      # @raise [NetworkError] If the API request fails
      def reload
        response = @client.get("namespaces/#{@namespace_id}/livestreams/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete the livestream
      #
      # After deletion, the resource is frozen and cannot be modified.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] If the API request fails
      def delete
        @client.delete("namespaces/#{@namespace_id}/livestreams/#{id}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Publish the livestream
      #
      # Makes the livestream available for playback. The livestream status
      # will transition to 'active' if the stream is receiving data.
      #
      # @return [self] Returns self for method chaining
      # @raise [NetworkError] If the API request fails
      def publish
        @client.put("namespaces/#{@namespace_id}/livestreams/#{id}/publish", {})
        reload
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Unpublish the livestream
      #
      # Stops playback availability. The livestream will no longer be accessible
      # to viewers.
      #
      # @return [self] Returns self for method chaining
      # @raise [NetworkError] If the API request fails
      def unpublish
        @client.put("namespaces/#{@namespace_id}/livestreams/#{id}/unpublish", {})
        reload
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Enable the livestream
      #
      # Re-enables a previously disabled livestream.
      #
      # @return [self] Returns self for method chaining
      # @raise [NetworkError] If the API request fails
      def enable
        @client.put("namespaces/#{@namespace_id}/livestreams/#{id}/enable", {})
        reload
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Disable the livestream
      #
      # Disables the livestream, preventing ingest and playback.
      #
      # @return [self] Returns self for method chaining
      # @raise [NetworkError] If the API request fails
      def disable
        @client.put("namespaces/#{@namespace_id}/livestreams/#{id}/disable", {})
        reload
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this livestream belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Convenience method: Get the current stream status
      #
      # @return [String] The stream status (e.g., 'idle', 'active')
      def status
        @current_attributes[:stream_status]
      end

      # Convenience method: Get the RTMP ingest URL
      #
      # @return [String, nil] The RTMP URL for streaming to this livestream
      def rtmp_url
        @current_attributes.dig(:stream_urls, :rtmp)
      end

      # Convenience method: Get the stream key (same as the livestream ID)
      #
      # The stream key is used in conjunction with the RTMP URL for streaming.
      # In the Pug API, the stream key is the livestream ID.
      #
      # @return [String] The stream key (livestream ID)
      def stream_key
        id
      end

      # Set simulcast targets (accepts UUIDs or SimulcastTarget objects)
      #
      # @param targets [Array<String, SimulcastTarget>] Array of UUIDs or SimulcastTarget objects
      # @raise [ValidationError] if SimulcastTarget object has no ID
      def simulcast_targets=(targets)
        ids = self.class.send(:extract_simulcast_target_ids, targets)

        validate_writable!(:simulcast_targets)
        mark_dirty!
        @current_attributes[:simulcast_targets] = ids
      end

      # Human-readable representation of the livestream
      #
      # @return [String]
      def inspect
        "#<#{self.class.name} id=#{id.inspect} status=#{status.inspect} changed=#{changed?}>"
      end

      # Extract IDs from SimulcastTarget objects or strings
      #
      # @param targets [Array<String, SimulcastTarget>] Array of UUIDs or SimulcastTarget objects
      # @return [Array<String>] Array of UUIDs
      # @raise [ValidationError] if SimulcastTarget object has no ID or wrong type
      def self.extract_simulcast_target_ids(targets)
        targets.map do |target|
          case target
          when String
            target
          when Resources::SimulcastTarget
            raise ValidationError, 'SimulcastTarget must have an ID (save it first)' if target.id.nil?

            target.id
          else
            raise ValidationError, "Expected String or SimulcastTarget, got #{target.class}"
          end
        end
      end
      private_class_method :extract_simulcast_target_ids
    end
  end
end
