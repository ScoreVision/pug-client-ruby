# frozen_string_literal: true

module PugClient
  module Resources
    # Playlist resource represents an ordered collection of videos within a namespace
    #
    # Playlists maintain ordered lists of video IDs with automatic version management.
    class Playlist < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
        version
        playback
      ].freeze

      attr_reader :namespace_id

      # Initialize a new Playlist resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this playlist belongs to
      # @param attributes [Hash] Playlist attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find a playlist by ID
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param playlist_id [String] The playlist ID
      # @param options [Hash] Additional options
      # @return [Playlist] The playlist resource
      # @raise [ResourceNotFound] If the playlist doesn't exist
      # @raise [NetworkError] If the API request fails
      def self.find(client, namespace_id, playlist_id, options = {})
        response = client.get("namespaces/#{namespace_id}/playlists/#{playlist_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        if e.is_a?(Faraday::ResourceNotFound) || (e.respond_to?(:response) && e.response&.status == 404)
          raise ResourceNotFound.new('Playlist', playlist_id)
        end

        raise NetworkError, e.message
      end

      # Get all playlists in a namespace
      #
      # @note This endpoint is intentionally not supported by this Ruby client.
      #   The API does not provide a playlist listing endpoint.
      #   Playlists can be created and retrieved individually by ID, but
      #   listing/pagination is not available.
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Additional options for filtering/pagination
      # @return [void]
      # @raise [FeatureNotSupportedError] Always raised - this feature is not supported
      #
      # @example Attempting to list playlists
      #   Playlist.all(client, 'my-namespace')
      #   # => raises FeatureNotSupportedError
      def self.all(_client, _namespace_id, _options = {})
        raise FeatureNotSupportedError.new(
          'Playlist listing',
          'The API does not provide an endpoint for listing playlists. ' \
          'Playlists can be created and retrieved individually by ID.'
        )
      end

      # Create a new playlist
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param video_ids [Array<String>] Ordered array of video IDs
      # @param options [Hash] Optional attributes (metadata)
      # @return [Playlist] The created playlist resource
      # @raise [NetworkError] If the API request fails
      # @example
      #   Playlist.create(client, 'my-namespace', ['video-1', 'video-2'])
      #   Playlist.create(client, 'my-namespace', ['video-1', 'video-2'],
      #     metadata: { labels: { type: 'highlights' } })
      def self.create(client, namespace_id, video_ids, options = {})
        # Ensure metadata is present (required by API)
        options = options.dup
        options[:metadata] ||= {}

        # Convert to API format (camelCase)
        attributes = AttributeTranslator.to_api(options)
        attributes[:videos] = video_ids

        body = {
          data: {
            type: 'playlists',
            attributes: attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/playlists", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate a playlist from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [Playlist] The playlist resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the playlist
      #
      # @raise [NotImplementedError] Playlist updates are not supported by the API
      def save
        raise NotImplementedError, 'Playlist updates are not supported by the API (no PATCH endpoint)'
      end

      # Reload the playlist from the API
      #
      # Discards any unsaved changes.
      #
      # @return [self]
      # @raise [NetworkError] If the API request fails
      def reload
        response = @client.get("namespaces/#{@namespace_id}/playlists/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete the playlist
      #
      # @raise [NotImplementedError] Playlist deletion is not supported by the API
      def delete
        raise NotImplementedError, 'Playlist deletion is not supported by the API (no DELETE endpoint)'
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this playlist belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Get the videos array
      #
      # @return [Array<String>] Array of video IDs
      def videos
        @current_attributes[:videos] || []
      end

      # Get video resources for this playlist
      #
      # @return [Array<Video>] Array of Video resources
      def video_resources
        videos.map { |video_id| Video.find(@client, @namespace_id, video_id) }
      end

      # Human-readable representation of the playlist
      #
      # @return [String]
      def inspect
        video_count = videos.size
        "#<#{self.class.name} id=#{id.inspect} videos=#{video_count} changed=#{changed?}>"
      end
    end
  end
end
