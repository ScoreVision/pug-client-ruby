# frozen_string_literal: true

module PugClient
  module Resources
    # Campaign resource represents a campaign within a namespace
    #
    # Campaigns use slug-based identifiers in API URLs while also having
    # a server-generated UUID id field.
    class Campaign < Resource
      # Attributes that cannot be modified after creation
      READ_ONLY_ATTRIBUTES = %i[
        id
        created_at
        updated_at
        version
      ].freeze

      attr_reader :namespace_id

      # Initialize a new Campaign resource
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID this campaign belongs to
      # @param attributes [Hash] Campaign attributes
      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find a campaign by ID or slug
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param campaign_id [String] The campaign ID or slug
      # @param options [Hash] Additional options
      # @return [Campaign] The campaign resource
      # @raise [ResourceNotFound] If the campaign doesn't exist
      # @raise [NetworkError] If the API request fails
      def self.find(client, namespace_id, campaign_id, options = {})
        response = client.get("namespaces/#{namespace_id}/campaigns/#{campaign_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        if e.is_a?(Faraday::ResourceNotFound) || (e.respond_to?(:response) && e.response&.status == 404)
          raise ResourceNotFound.new('Campaign', campaign_id)
        end

        raise NetworkError, e.message
      end

      # Get all campaigns in a namespace
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param options [Hash] Additional options for filtering/pagination
      # @return [ResourceEnumerator] Enumerator for lazy loading campaigns
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          base_url: "namespaces/#{namespace_id}/campaigns",
          resource_class: self,
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create a new campaign
      #
      # @param client [PugClient::Client] The API client
      # @param namespace_id [String] The namespace ID
      # @param name [String] The campaign display name (required, 2-256 chars)
      # @param slug [String] The campaign slug identifier (required, 1-32 chars, alphanumeric + dashes)
      # @param options [Hash] Optional attributes (preroll_video_id, postroll_video_id,
      #   start_time, end_time, metadata)
      # @return [Campaign] The created campaign resource
      # @raise [NetworkError] If the API request fails
      def self.create(client, namespace_id, name, slug, options = {})
        # Convert Time objects to ISO8601 strings
        options = options.dup
        options[:start_time] = options[:start_time].utc.iso8601 if options[:start_time].is_a?(Time)
        options[:end_time] = options[:end_time].utc.iso8601 if options[:end_time].is_a?(Time)

        # Add required fields
        options[:name] = name
        options[:slug] = slug

        # Convert to API format (camelCase)
        attributes = AttributeTranslator.to_api(options)

        body = {
          data: {
            type: 'campaigns',
            attributes: attributes
          }
        }

        response = client.post("namespaces/#{namespace_id}/campaigns", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Instantiate a campaign from API response data
      #
      # @param client [PugClient::Client] The API client
      # @param data [Hash] The API response data
      # @param options [Hash] Additional options (_namespace_id required)
      # @return [Campaign] The campaign resource
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:namespace_id] || options[:_namespace_id] || data.dig(:metadata, :namespace)
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes to the campaign
      #
      # Uses JSON Patch (RFC 6902) to send only changed attributes.
      # Note: Uses slug in the URL, not id.
      #
      # @return [Boolean] true if saved successfully
      # @raise [NetworkError] If the API request fails
      def save
        return true unless changed?

        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/campaigns/#{slug}", { data: operations })

        load_attributes(response)
        clear_dirty!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Reload the campaign from the API
      #
      # Discards any unsaved changes.
      # Note: Uses slug in the URL, not id.
      #
      # @return [self]
      # @raise [NetworkError] If the API request fails
      def reload
        response = @client.get("namespaces/#{@namespace_id}/campaigns/#{slug}")
        load_attributes(response)
        clear_dirty!
        self
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Delete the campaign
      #
      # After deletion, the resource is frozen and cannot be modified.
      # Note: Uses slug in the URL, not id.
      #
      # @return [Boolean] true if deleted successfully
      # @raise [NetworkError] If the API request fails
      def delete
        @client.delete("namespaces/#{@namespace_id}/campaigns/#{slug}")
        freeze_resource!
        true
      rescue StandardError => e
        raise NetworkError, e.message
      end

      # Get the parent namespace
      #
      # @return [Namespace] The namespace this campaign belongs to
      def namespace
        @namespace ||= Namespace.find(@client, @namespace_id)
      end

      # Get the campaign slug (used in API URLs)
      #
      # @return [String] The campaign slug
      def slug
        @current_attributes[:slug]
      end

      # Get the preroll video if preroll_video_id is set
      #
      # @return [Video, nil] The preroll video or nil
      def preroll_video
        return nil unless @current_attributes[:preroll_video_id]

        @preroll_video ||= Video.find(@client, @namespace_id, @current_attributes[:preroll_video_id])
      end

      # Get the postroll video if postroll_video_id is set
      #
      # @return [Video, nil] The postroll video or nil
      def postroll_video
        return nil unless @current_attributes[:postroll_video_id]

        @postroll_video ||= Video.find(@client, @namespace_id, @current_attributes[:postroll_video_id])
      end

      # Human-readable representation of the campaign
      #
      # @return [String]
      def inspect
        "#<#{self.class.name} id=#{id.inspect} slug=#{slug.inspect} changed=#{changed?}>"
      end
    end
  end
end
