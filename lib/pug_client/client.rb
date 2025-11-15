# frozen_string_literal: true

module PugClient
  # API client for the Pug Video API
  #
  # The Client class provides access to all Pug Video API resources through
  # a modular, composable design using mixins.
  #
  # @example Create a production client
  #   client = PugClient::Client.new(
  #     client_id: ENV['PUG_CLIENT_ID'],
  #     client_secret: ENV['PUG_CLIENT_SECRET']
  #   )
  #
  # @example Create a staging client
  #   client = PugClient::Client.new(
  #     environment: :staging,
  #     client_id: ENV['PUG_CLIENT_ID'],
  #     client_secret: ENV['PUG_CLIENT_SECRET']
  #   )
  #
  # @example Use custom endpoints
  #   client = PugClient::Client.new(
  #     api_endpoint: 'http://localhost:3000',
  #     auth_endpoint: 'http://localhost:3001/oauth/token',
  #     client_id: 'test',
  #     client_secret: 'test'
  #   )
  class Client
    # Core modules (shared between old and new architecture)
    include PugClient::Configurable
    include PugClient::Connection
    include PugClient::Authentication

    # ============================================================================
    # LEGACY: Old client-centric module architecture (TO BE REMOVED - ALL MODULES MIGRATED!)
    # These modules provide direct API methods on the client.
    # They will be replaced with resource-based classes in lib/pug_client/resources/
    # ============================================================================
    # All legacy modules have been migrated to resource-based pattern!
    # ============================================================================
    # END LEGACY
    # ============================================================================

    # Initialize a new Client instance
    #
    # @param options [Hash] Configuration options
    # @option options [Symbol] :environment Environment preset (:production or :staging)
    # @option options [String] :namespace Default namespace for all resource operations (required)
    # @option options [String] :api_endpoint API base URL
    # @option options [String] :auth_endpoint Auth0 OAuth2 token endpoint
    # @option options [String] :auth_audience OAuth2 audience identifier
    # @option options [String] :auth_grant_type OAuth2 grant type (default: 'client_credentials')
    # @option options [String] :client_id OAuth2 client ID
    # @option options [String] :client_secret OAuth2 client secret
    # @option options [Integer] :per_page Default pagination page size (default: 10)
    # @option options [Boolean] :auto_paginate Automatically paginate through all results
    # @option options [Hash] :connection_options Faraday connection options
    # @return [PugClient::Client]
    # @raise [ArgumentError] if namespace is not provided
    def initialize(options = {})
      # Extract environment and determine defaults
      environment = options.delete(:environment) || :production
      defaults = environment_defaults(environment)

      # Merge: environment defaults < instance options
      PugClient::Configurable.keys.each do |key|
        value = options.key?(key) ? options[key] : defaults[key]
        instance_variable_set(:"@#{key}", value)
      end

      # Validate required namespace
      raise ArgumentError, 'namespace is required' unless @namespace
    end

    # Check if two clients have the same configuration options
    #
    # @param opts [Hash] Options hash to compare
    # @return [Boolean]
    def same_options?(opts)
      opts.hash == options.hash
    end

    # Get current client configuration as a hash
    #
    # @return [Hash] Hash of all configuration options and their values
    def options
      Hash[PugClient::Configurable.keys.map { |key| [key, instance_variable_get(:"@#{key}")] }]
    end

    # Resource object methods (new API)
    #
    # These methods return resource objects that provide a more object-oriented
    # interface to the API, with features like dirty tracking, automatic JSON Patch
    # generation, and lazy enumeration.

    # Get a namespace by ID
    #
    # Fetches a namespace resource from the API. If no ID is provided,
    # uses the client's configured default namespace.
    #
    # @param id [String, nil] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::Namespace] Namespace resource
    # @raise [ResourceNotFound] if namespace doesn't exist
    # @example Fetch configured namespace
    #   namespace = client.namespace
    #   puts namespace.metadata
    # @example Fetch specific namespace
    #   namespace = client.namespace('other-namespace')
    #   puts namespace.metadata
    def namespace(id = @namespace, **options)
      Resources::Namespace.find(self, id, options)
    end

    # Create a new namespace
    #
    # @param id [String] Namespace identifier
    # @param options [Hash] Optional parameters (metadata, etc.)
    # @return [Resources::Namespace] Created namespace resource
    # @example
    #   namespace = client.create_namespace('my-namespace',
    #     metadata: { labels: { env: 'prod' } }
    #   )
    def create_namespace(id, options = {})
      Resources::Namespace.create(self, id, options)
    end

    # List all namespaces (returns lazy enumerator)
    #
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for namespaces
    # @example
    #   client.namespaces.each { |ns| puts ns.id }
    #   client.namespaces.first(10)
    def namespaces(options = {})
      Resources::Namespace.all(self, options)
    end

    # List user's namespaces (returns lazy enumerator)
    #
    # @param options [Hash] Optional parameters
    # @return [ResourceEnumerator] Lazy enumerator for user's namespaces
    # @example
    #   client.user_namespaces.to_a
    def user_namespaces(options = {})
      Resources::Namespace.for_user(self, options)
    end

    # Get a video by ID
    #
    # @param video_id [String] Video identifier
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::Video] Video resource
    # @raise [ResourceNotFound] if video doesn't exist
    # @example
    #   video = client.video('video-123')
    #   puts video.started_at
    # @example Override namespace
    #   video = client.video('video-123', namespace: 'other-namespace')
    def video(video_id, namespace: @namespace, **options)
      Resources::Video.find(self, namespace, video_id, options)
    end

    # Create a new video
    #
    # @param started_at [String, Time] Video start timestamp
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (metadata, etc.)
    # @return [Resources::Video] Created video resource
    # @example
    #   video = client.create_video(Time.now.utc.iso8601,
    #     metadata: { labels: { game: 'basketball' } }
    #   )
    def create_video(started_at, namespace: @namespace, **options)
      Resources::Video.create(self, namespace, started_at, options)
    end

    # List videos in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for videos
    # @example
    #   client.videos.each { |v| puts v.id }
    #   client.videos.first(10)
    # @example Override namespace
    #   client.videos(namespace: 'other-namespace').first(10)
    def videos(namespace: @namespace, **options)
      Resources::Video.all(self, namespace, options)
    end

    # Fetch a specific livestream by ID
    #
    # @param livestream_id [String] LiveStream ID
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::LiveStream] LiveStream resource
    # @raise [ResourceNotFound] if livestream doesn't exist
    # @example
    #   livestream = client.livestream('livestream-123')
    #   puts livestream.status
    def livestream(livestream_id, namespace: @namespace, **options)
      Resources::LiveStream.find(self, namespace, livestream_id, options)
    end

    # Create a new livestream
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (started_at, metadata, location,
    #   simulcast_targets)
    # @return [Resources::LiveStream] Created livestream resource
    # @example
    #   livestream = client.create_livestream(
    #     started_at: Time.now,
    #     metadata: { labels: { event: 'championship' } }
    #   )
    def create_livestream(namespace: @namespace, **options)
      Resources::LiveStream.create(self, namespace, options)
    end

    # List livestreams in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for livestreams
    # @example
    #   client.livestreams.each { |ls| puts ls.status }
    #   client.livestreams.first(10)
    def livestreams(namespace: @namespace, **options)
      Resources::LiveStream.all(self, namespace, options)
    end

    # Fetch a specific campaign by ID or slug
    #
    # @param campaign_id [String] Campaign ID or slug
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::Campaign] Campaign resource
    # @raise [ResourceNotFound] if campaign doesn't exist
    # @example
    #   campaign = client.campaign('summer-2024')
    #   puts campaign.slug
    def campaign(campaign_id, namespace: @namespace, **options)
      Resources::Campaign.find(self, namespace, campaign_id, options)
    end

    # Create a new campaign
    #
    # @param name [String] Campaign display name (required, 2-256 chars)
    # @param slug [String] Campaign slug identifier (required, 1-32 chars, alphanumeric + dashes)
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (preroll_video_id, postroll_video_id,
    #   start_time, end_time, metadata)
    # @return [Resources::Campaign] Created campaign resource
    # @example
    #   campaign = client.create_campaign('Winter 2024 Campaign', 'winter-2024',
    #     start_time: Time.utc(2024, 12, 1),
    #     metadata: { labels: { season: 'winter' } }
    #   )
    def create_campaign(name, slug, namespace: @namespace, **options)
      Resources::Campaign.create(self, namespace, name, slug, options)
    end

    # List campaigns in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for campaigns
    # @example
    #   client.campaigns.each { |c| puts c.slug }
    #   client.campaigns.first(10)
    def campaigns(namespace: @namespace, **options)
      Resources::Campaign.all(self, namespace, options)
    end

    # Create a namespace client credential
    #
    # @note **This feature is intentionally not supported by this Ruby client.**
    #   Namespace client creation is excluded for security and architectural reasons.
    #   Please use the web console or contact your administrator to create
    #   namespace-scoped credentials.
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [void]
    # @raise [FeatureNotSupportedError] Always raised - this feature is not supported
    #
    # @example Attempting to create a namespace client
    #   client.create_namespace_client
    #   # => raises FeatureNotSupportedError
    #
    # @see FeatureNotSupportedError
    def create_namespace_client(namespace: @namespace, **_options)
      raise FeatureNotSupportedError.new(
        'Namespace client creation',
        'This endpoint is intentionally excluded from the Ruby client. ' \
        'Please use the web console or contact your administrator to create namespace credentials.'
      )
    end

    # Fetch a specific playlist by ID
    #
    # @param playlist_id [String] Playlist ID
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::Playlist] Playlist resource
    # @raise [ResourceNotFound] if playlist doesn't exist
    # @example
    #   playlist = client.playlist('playlist-123')
    #   puts playlist.videos
    def playlist(playlist_id, namespace: @namespace, **options)
      Resources::Playlist.find(self, namespace, playlist_id, options)
    end

    # Create a new playlist
    #
    # @param video_ids [Array<String>] Ordered array of video IDs
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (metadata)
    # @return [Resources::Playlist] Created playlist resource
    # @example
    #   playlist = client.create_playlist(['video-1', 'video-2'])
    #   playlist = client.create_playlist(['video-1', 'video-2'],
    #     metadata: { labels: { type: 'highlights' } }
    #   )
    def create_playlist(video_ids, namespace: @namespace, **options)
      Resources::Playlist.create(self, namespace, video_ids, options)
    end

    # List playlists in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for playlists
    # @example
    #   client.playlists.each { |playlist| puts playlist.id }
    #   client.playlists.first(10)
    def playlists(namespace: @namespace, **options)
      Resources::Playlist.all(self, namespace, options)
    end

    # Fetch a specific simulcast target by ID
    #
    # @param target_id [String] SimulcastTarget ID
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::SimulcastTarget] SimulcastTarget resource
    # @raise [ResourceNotFound] if simulcast target doesn't exist
    # @example
    #   target = client.simulcast_target('target-123')
    #   puts target.url
    def simulcast_target(target_id, namespace: @namespace, **options)
      Resources::SimulcastTarget.find(self, namespace, target_id, options)
    end

    # Create a new simulcast target
    #
    # @param url [String] RTMP URL to forward stream to
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (metadata)
    # @return [Resources::SimulcastTarget] Created simulcast target resource
    # @example
    #   target = client.create_simulcast_target('rtmp://youtube.com/live/streamkey')
    #   target = client.create_simulcast_target('rtmp://youtube.com/live/streamkey',
    #     metadata: { labels: { platform: 'youtube' } }
    #   )
    def create_simulcast_target(url, namespace: @namespace, **options)
      Resources::SimulcastTarget.create(self, namespace, url, options)
    end

    # List simulcast targets in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for simulcast targets
    # @example
    #   client.simulcast_targets.each { |target| puts target.url }
    #   client.simulcast_targets.first(10)
    def simulcast_targets(namespace: @namespace, **options)
      Resources::SimulcastTarget.all(self, namespace, options)
    end

    # Fetch a specific webhook by ID
    #
    # @param webhook_id [String] Webhook ID
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters
    # @return [Resources::Webhook] Webhook resource
    # @raise [ResourceNotFound] if webhook doesn't exist
    # @example
    #   webhook = client.webhook('webhook-123')
    #   puts webhook.url
    def webhook(webhook_id, namespace: @namespace, **options)
      Resources::Webhook.find(self, namespace, webhook_id, options)
    end

    # Create a new webhook
    #
    # @param url [String] Webhook endpoint URL
    # @param actions [Array<String>] Event actions to trigger webhook
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (metadata)
    # @return [Resources::Webhook] Created webhook resource
    # @example
    #   webhook = client.create_webhook(
    #     'https://my.endpoint.com/webhooks',
    #     ['video.ready', 'livestream.published']
    #   )
    def create_webhook(url, actions, namespace: @namespace, **options)
      Resources::Webhook.create(self, namespace, url, actions, options)
    end

    # List webhooks in a namespace (returns lazy enumerator)
    #
    # @param namespace [String] Namespace identifier (defaults to configured namespace)
    # @param options [Hash] Optional parameters (query filters, pagination)
    # @return [ResourceEnumerator] Lazy enumerator for webhooks
    # @example
    #   client.webhooks.each { |webhook| puts webhook.url }
    #   client.webhooks.first(10)
    def webhooks(namespace: @namespace, **options)
      Resources::Webhook.all(self, namespace, options)
    end

    private

    # Get default configuration for the specified environment
    #
    # @param environment [Symbol] The environment (:production or :staging)
    # @return [Hash] Default configuration options for the environment
    # @raise [ArgumentError] if environment is not :production or :staging
    # @api private
    def environment_defaults(environment)
      case environment
      when :staging
        PugClient::DefaultStaging.options
      when :production
        PugClient::DefaultProduction.options
      else
        raise ArgumentError, "Unknown environment: #{environment}. Use :production or :staging"
      end
    end
  end
end
