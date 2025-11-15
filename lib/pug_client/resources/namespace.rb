# frozen_string_literal: true

module PugClient
  module Resources
    # Namespace resource
    #
    # Represents a namespace in the Pug Video API. Namespaces are containers
    # for organizing videos, live streams, and other resources.
    #
    # @example Find a namespace
    #   namespace = client.namespace('my-namespace')
    #   puts namespace.id
    #
    # @example Create a namespace
    #   namespace = client.create_namespace('my-namespace',
    #     metadata: { labels: { env: 'prod' } }
    #   )
    #
    # @example Update namespace metadata
    #   namespace.metadata[:labels][:status] = 'active'
    #   namespace.save
    #
    # @example List videos in namespace
    #   namespace.videos.each { |video| puts video.id }
    class Namespace < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[id created_at updated_at].freeze

      # Find namespace by ID
      #
      # @param client [Client] The API client
      # @param id [String] Namespace identifier
      # @param options [Hash] Optional parameters
      # @return [Namespace] The namespace resource
      # @raise [ResourceNotFound] if namespace doesn't exist
      # @raise [NetworkError] if API request fails
      def self.find(client, id, options = {})
        response = client.get("namespaces/#{id}", options)
        new(client: client, attributes: response)
      rescue StandardError => e
        raise ResourceNotFound.new('Namespace', id) if e.respond_to?(:response) && e.response&.status == 404

        raise NetworkError, e.message
      end

      # Create new namespace
      #
      # @param client [Client] The API client
      # @param id [String] Namespace identifier (3-64 characters)
      # @param options [Hash] Optional parameters (metadata, etc.)
      # @return [Namespace] The created namespace
      # @raise [ValidationError] if namespace ID is invalid
      # @raise [NetworkError] if API request fails
      def self.create(client, id, options = {})
        # Convert options to API format
        api_attributes = AttributeTranslator.to_api(options)

        body = {
          data: {
            type: 'namespaces',
            id: id,
            attributes: api_attributes
          }
        }

        response = client.post('namespaces', body)
        new(client: client, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # List all namespaces (returns enumerator)
      #
      # @param client [Client] The API client
      # @param options [Hash] Optional parameters (query filters, pagination)
      # @return [ResourceEnumerator] Lazy enumerator for namespaces
      # @example
      #   PugClient::Resources::Namespace.all(client).each { |ns| puts ns.id }
      #   PugClient::Resources::Namespace.all(client).first(10)
      def self.all(client, options = {})
        ResourceEnumerator.new(
          client: client,
          resource_class: self,
          base_url: 'namespaces',
          options: options
        )
      end

      # List user's namespaces (returns enumerator)
      #
      # @param client [Client] The API client
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for user's namespaces
      # @example
      #   PugClient::Resources::Namespace.for_user(client).to_a
      def self.for_user(client, options = {})
        ResourceEnumerator.new(
          client: client,
          resource_class: self,
          base_url: 'user/namespaces',
          options: options
        )
      end

      # Instantiate from API data (used by ResourceEnumerator)
      #
      # @param client [Client] The API client
      # @param data [Hash] Raw API response data
      # @param options [Hash] Additional options (unused for namespaces)
      # @return [Namespace] New namespace instance
      # @api private
      def self.from_api_data(client, data, _options = {})
        new(client: client, attributes: data)
      end

      # Save changes to namespace
      #
      # Generates JSON Patch operations from tracked changes and sends to API.
      # Returns true if there were no changes or save succeeded.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] if API request fails
      # @example
      #   namespace.metadata[:labels][:env] = 'staging'
      #   namespace.save  # Sends JSON Patch to API
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{id}", { data: operations })
        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload namespace from API
      #
      # Discards any unsaved changes and reloads from API.
      #
      # @return [self]
      # @raise [NetworkError] if API request fails
      # @example
      #   namespace.reload
      #   puts namespace.metadata
      def reload
        response = @client.get("namespaces/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete namespace
      #
      # Deletes the namespace from the API and freezes the object to prevent
      # further modifications.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] if API request fails
      # @example
      #   namespace.delete
      def delete
        @client.delete("namespaces/#{id}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get videos in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters (query filters, pagination)
      # @return [ResourceEnumerator] Lazy enumerator for videos
      # @example
      #   namespace.videos.each { |video| puts video.id }
      #   namespace.videos.first(10)
      def videos(options = {})
        Video.all(@client, id, options)
      end

      # Create a video in this namespace
      #
      # @param started_at [String, Time] Video start timestamp (ISO 8601)
      # @param options [Hash] Optional parameters (metadata, etc.)
      # @return [Video] The created video
      # @example
      #   video = namespace.create_video(Time.now.utc.iso8601,
      #     metadata: { labels: { game: 'championship' } }
      #   )
      def create_video(started_at, options = {})
        Video.create(@client, id, started_at, options)
      end

      # Get live streams in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for live streams
      def livestreams(options = {})
        LiveStream.all(@client, id, options)
      end

      # Create a livestream in this namespace
      #
      # @param options [Hash] Optional parameters (started_at, metadata, location,
      #   simulcast_targets)
      # @return [LiveStream] The created livestream
      # @example
      #   livestream = namespace.create_livestream(
      #     started_at: Time.now,
      #     metadata: { labels: { event: 'championship' } }
      #   )
      def create_livestream(options = {})
        LiveStream.create(@client, id, options)
      end

      # Get campaigns in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for campaigns
      def campaigns(options = {})
        Campaign.all(@client, id, options)
      end

      # Create a campaign in this namespace
      #
      # @param name [String] Campaign display name (required, 2-256 chars)
      # @param slug [String] Campaign slug identifier (required, 1-32 chars, alphanumeric + dashes)
      # @param options [Hash] Optional parameters (preroll_video_id, postroll_video_id,
      #   start_time, end_time, metadata)
      # @return [Campaign] The created campaign
      # @example
      #   campaign = namespace.create_campaign('Summer 2024 Campaign', 'summer-2024',
      #     start_time: Time.utc(2024, 6, 1),
      #     metadata: { labels: { season: 'summer' } }
      #   )
      def create_campaign(name, slug, options = {})
        Campaign.create(@client, id, name, slug, options)
      end

      # Get simulcast targets in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for simulcast targets
      # @example
      #   namespace.simulcast_targets.each { |target| puts target.url }
      def simulcast_targets(options = {})
        SimulcastTarget.all(@client, id, options)
      end

      # Create a simulcast target in this namespace
      #
      # @param url [String] RTMP URL to forward stream to
      # @param options [Hash] Optional parameters (metadata)
      # @return [SimulcastTarget] The created simulcast target
      # @example
      #   target = namespace.create_simulcast_target('rtmp://youtube.com/live/streamkey',
      #     metadata: { labels: { platform: 'youtube' } }
      #   )
      def create_simulcast_target(url, options = {})
        SimulcastTarget.create(@client, id, url, options)
      end

      # Get webhooks in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for webhooks
      # @example
      #   namespace.webhooks.each { |webhook| puts webhook.url }
      def webhooks(options = {})
        Webhook.all(@client, id, options)
      end

      # Create a webhook in this namespace
      #
      # @param url [String] Webhook endpoint URL
      # @param actions [Array<String>] Event actions to trigger webhook
      # @param options [Hash] Optional parameters (metadata)
      # @return [Webhook] The created webhook
      # @example
      #   webhook = namespace.create_webhook(
      #     'https://my.endpoint.com/webhooks',
      #     ['video.ready', 'livestream.published'],
      #     metadata: { labels: { environment: 'production' } }
      #   )
      def create_webhook(url, actions, options = {})
        Webhook.create(@client, id, url, actions, options)
      end

      # Get playlists in this namespace (lazy enumerator)
      #
      # @param options [Hash] Optional parameters
      # @return [ResourceEnumerator] Lazy enumerator for playlists
      # @example
      #   namespace.playlists.each { |playlist| puts playlist.id }
      def playlists(options = {})
        Playlist.all(@client, id, options)
      end

      # Create a playlist in this namespace
      #
      # @param video_ids [Array<String>] Ordered array of video IDs
      # @param options [Hash] Optional parameters (metadata)
      # @return [Playlist] The created playlist
      # @example
      #   playlist = namespace.create_playlist(['video-1', 'video-2'],
      #     metadata: { labels: { type: 'highlights' } }
      #   )
      def create_playlist(video_ids, options = {})
        Playlist.create(@client, id, video_ids, options)
      end

      # Get clients in this namespace
      #
      # Note: The API does not support listing namespace clients for security reasons.
      # You can only create new clients via {#create_client}.
      #
      # @param options [Hash] Optional parameters
      # @raise [NotImplementedError] The API does not support listing clients
      def clients(options = {})
        raise NotImplementedError,
              'The API does not support listing namespace clients for security reasons. ' \
              'Use #create_client to create new credentials.'
      end

      # Create a client credential for this namespace
      #
      # Creates namespace-scoped authentication credentials. The secret is only
      # returned once during creation and cannot be retrieved again.
      #
      # IMPORTANT: Capture and store the secret immediately!
      #
      # @param options [Hash] Optional parameters (metadata)
      # @return [NamespaceClient] The created namespace client with id and secret
      # @example
      #   client_credential = namespace.create_client
      #   puts "Client ID: #{client_credential.id}"
      #   puts "Secret: #{client_credential.secret}"  # Save this!
      #
      #   # Use the credentials
      #   scoped_client = PugClient::Client.new(
      #     client_id: client_credential.id,
      #     client_secret: client_credential.secret
      #   )
      def create_client(options = {})
        NamespaceClient.create(@client, id, options)
      end
    end
  end
end
