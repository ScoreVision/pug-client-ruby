# frozen_string_literal: true

module PugClient
  module Resources
    # Video resource
    #
    # Represents a video in the Pug Video API. Videos belong to namespaces
    # and contain video content, metadata, and playback information.
    #
    # @example Find a video
    #   video = client.video('my-namespace', 'video-123')
    #   puts video.started_at
    #
    # @example Create a video
    #   video = namespace.create_video(Time.now.utc.iso8601,
    #     metadata: { labels: { game: 'championship' } }
    #   )
    #
    # @example Update video metadata
    #   video.metadata[:labels][:status] = 'reviewed'
    #   video.save
    #
    # @example Create a clip
    #   clip = video.clip(start_time: 5000, duration: 30000)
    class Video < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id created_at updated_at duration started_at
        renditions playback_urls thumbnail_url playback source
      ].freeze

      # Supported video content types for upload
      SUPPORTED_CONTENT_TYPES = ['video/mp4'].freeze

      attr_reader :namespace_id

      # Initialize a video resource
      #
      # @param client [Client] The API client
      # @param namespace_id [String] Namespace identifier
      # @param attributes [Hash] Video attributes
      # @api private
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find video by ID
      #
      # @param client [Client] The API client
      # @param namespace_id [String] Namespace identifier
      # @param video_id [String] Video identifier
      # @param options [Hash] Optional parameters
      # @return [Video] The video resource
      # @raise [ResourceNotFound] if video doesn't exist
      # @raise [NetworkError] if API request fails
      def self.find(client, namespace_id, video_id, options = {})
        response = client.get("namespaces/#{namespace_id}/videos/#{video_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        # Treat both 404 and 422 (invalid ID format) as ResourceNotFound
        if e.respond_to?(:response)
          status = e.response&.status
          raise ResourceNotFound.new('Video', video_id) if [404, 422].include?(status)
        end

        raise NetworkError, e.message
      end

      # List videos in namespace (returns enumerator)
      #
      # @param client [Client] The API client
      # @param namespace_id [String] Namespace identifier
      # @param options [Hash] Optional parameters (query filters, pagination)
      # @return [ResourceEnumerator] Lazy enumerator for videos
      # @example
      #   Video.all(client, 'my-namespace').each { |v| puts v.id }
      #   Video.all(client, 'my-namespace').first(10)
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          resource_class: self,
          base_url: "namespaces/#{namespace_id}/videos",
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create new video
      #
      # @param client [Client] The API client
      # @param namespace_id [String] Namespace identifier
      # @param started_at [String, Time] Video start timestamp (ISO 8601)
      # @param options [Hash] Optional parameters (metadata, location, source, duration)
      # @return [Video] The created video
      # @raise [NetworkError] if API request fails
      def self.create(client, namespace_id, started_at, options = {})
        # Convert Time to ISO8601 string
        started_at_value = started_at.is_a?(Time) ? started_at.iso8601 : started_at

        # Convert options to API format
        api_attributes = AttributeTranslator.to_api(options)
        api_attributes[:startedAt] = started_at_value

        body = {
          data: {
            type: 'videos',
            attributes: api_attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/videos", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate from API data (used by ResourceEnumerator)
      #
      # @param client [Client] The API client
      # @param data [Hash] Raw API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [Video] New video instance
      # @api private
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to video
      #
      # Generates JSON Patch operations from tracked changes and sends to API.
      # Returns true if there were no changes or save succeeded.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] if API request fails
      # @example
      #   video.metadata[:labels][:status] = 'processed'
      #   video.save  # Sends JSON Patch to API
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/videos/#{id}", { data: operations })
        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload video from API
      #
      # Discards any unsaved changes and reloads from API.
      #
      # @return [self]
      # @raise [NetworkError] if API request fails
      # @example
      #   video.reload
      #   puts video.renditions
      def reload
        response = @client.get("namespaces/#{@namespace_id}/videos/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete video
      #
      # Deletes the video from the API and freezes the object to prevent
      # further modifications.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] if API request fails
      # @example
      #   video.delete
      def delete
        @client.delete("namespaces/#{@namespace_id}/videos/#{id}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Create a clip from this video
      #
      # Creates a new video resource from a portion of the current video.
      #
      # @param start_time [Integer] Start time in milliseconds
      # @param duration [Integer] Duration in milliseconds
      # @param options [Hash] Optional parameters (metadata, etc.)
      # @return [Video] The newly created clip video
      # @raise [NetworkError] if API request fails
      # @example
      #   clip = video.clip(start_time: 5000, duration: 30000,
      #     metadata: { labels: { type: 'highlight' } }
      #   )
      def clip(start_time:, duration:, **options)
        # Convert options to API format (command is required by API)
        api_attributes = AttributeTranslator.to_api(
          options.merge(
            command: 'clip',
            start_time: start_time,
            duration: duration
          )
        )

        body = {
          data: {
            attributes: api_attributes
          }
        }

        response = @client.post("namespaces/#{@namespace_id}/videos/#{id}/commands", body)
        Video.new(client: @client, namespace_id: @namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get signed upload URL for video file
      #
      # @param filename [String] Filename for the upload
      # @param options [Hash] Optional parameters
      # @return [Hash] Upload information with :url, :expiration, :headers keys
      # @raise [NetworkError] if API request fails
      # @example
      #   upload_info = video.upload_url('video.mp4')
      #   puts upload_info[:url]
      def upload_url(filename, **options)
        response = @client.get("namespaces/#{@namespace_id}/videos/#{id}/upload-urls/#{filename}", options)
        # Response is a hash, extract attributes and translate to Ruby conventions
        attrs = response.dig(:data, :attributes) || response[:attributes] || response
        AttributeTranslator.from_api(attrs)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Upload a video file
      #
      # Gets a signed upload URL and uploads the file directly to cloud storage.
      # Currently only MP4 files are supported.
      #
      # @param file_io [IO] IO object containing the file data
      # @param filename [String] Filename for the upload
      # @param content_type [String] Content type (default: 'video/mp4')
      # @return [Boolean] true if upload succeeded
      # @raise [ValidationError] if content type is not supported
      # @raise [NetworkError] if upload fails
      # @example
      #   File.open('video.mp4', 'rb') do |file|
      #     video.upload(file, filename: 'video.mp4')
      #   end
      #   video.wait_until_ready
      def upload(file_io, filename:, content_type: 'video/mp4')
        # Validate content type
        unless SUPPORTED_CONTENT_TYPES.include?(content_type)
          raise ValidationError,
                "Unsupported content type: #{content_type}. " \
                "Currently only #{SUPPORTED_CONTENT_TYPES.join(', ')} is supported."
        end

        upload_info = upload_url(filename)

        # Create separate Faraday connection for direct cloud storage upload
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end

        response = conn.put(upload_info[:url]) do |req|
          # Apply headers from signed URL response if present
          upload_info[:headers]&.each { |k, v| req.headers[k] = v }
          req.headers['Content-Type'] = content_type
          req.body = file_io.read
        end

        raise NetworkError, "Upload failed: #{response.status}" unless response.success?

        true
      rescue ValidationError
        raise
      rescue StandardError => e
        raise NetworkError, e.message unless e.is_a?(NetworkError)

        raise
      end

      # Wait for video to be ready for playback
      #
      # Polls the video resource until renditions are available, indicating
      # that video processing is complete.
      #
      # @param timeout [Integer] Maximum time to wait in seconds (default: 300)
      # @param interval [Integer] Polling interval in seconds (default: 5)
      # @return [Boolean] true when video is ready
      # @raise [TimeoutError] if video is not ready within timeout period
      # @example
      #   video.upload(file, filename: 'video.mp4')
      #   video.wait_until_ready(timeout: 600)
      #   puts video.playback_urls
      def wait_until_ready(timeout: 300, interval: 5)
        start_time = Time.now

        loop do
          reload

          # Check if video is ready (has renditions)
          return true if renditions && !renditions.empty?

          elapsed = Time.now - start_time
          raise TimeoutError, "Video not ready after #{timeout}s" if elapsed > timeout

          sleep interval
        end
      end

      # Get the namespace this video belongs to
      #
      # @return [Namespace] The parent namespace
      # @example
      #   video.namespace.metadata
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end
    end
  end
end
