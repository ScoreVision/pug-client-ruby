# frozen_string_literal: true

module PugClient
  # Lazy enumerator for paginated API resources
  #
  # Wraps paginated API calls and provides Ruby Enumerable interface.
  # Fetches pages on-demand during iteration, enabling efficient handling
  # of large collections without loading everything into memory.
  #
  # @example Lazy iteration
  #   namespace.videos.each { |video| puts video.id }
  #
  # @example Limit iteration
  #   namespace.videos.first(10)  # Only fetches enough pages for 10 items
  #
  # @example Force eager loading
  #   all_videos = namespace.videos.to_a
  class ResourceEnumerator
    include Enumerable

    attr_reader :client, :resource_class, :base_url, :options

    # Initialize a new ResourceEnumerator
    #
    # @param client [Client] The API client
    # @param resource_class [Class] The resource class to instantiate (e.g., Video, Namespace)
    # @param base_url [String] The API endpoint URL
    # @param options [Hash] Additional options (query params, namespace_id, etc.)
    def initialize(client:, resource_class:, base_url:, options: {})
      @client = client
      @resource_class = resource_class
      @base_url = base_url
      @options = options
    end

    # Enumerate over all resources
    #
    # Fetches pages on-demand and yields each resource to the block.
    # If no block given, returns an Enumerator.
    #
    # @yield [resource] Each resource instance
    # @return [Enumerator, nil]
    def each(&block)
      return enum_for(:each) unless block_given?

      fetch_pages(&block)
    end

    # Get first N items
    #
    # Optimizes by only fetching enough pages to satisfy the request.
    #
    # @param n [Integer, nil] Number of items to fetch (nil for first item)
    # @return [Object, Array] First item or array of first N items
    def first(n = nil)
      if n.nil?
        # Get first single item
        each { |item| return item }
        nil
      else
        # Get first N items
        items = []
        each do |item|
          items << item
          break if items.size >= n
        end
        items
      end
    end

    # Force eager loading of all items
    #
    # @return [Array] Array of all resources
    def to_a
      items = []
      each { |item| items << item }
      items
    end

    private

    # Fetch pages and yield each resource
    #
    # Automatically follows pagination links until no more pages.
    #
    # @yield [resource] Each resource instance
    # @api private
    def fetch_pages(&block)
      url = @base_url
      # Build params hash to pass to client.get
      params = {}
      params[:query] = @options[:query] if @options[:query]

      # Set default page size (needs to be under :query key for Connection)
      params[:query] ||= {}
      params[:query][:page] ||= {}
      params[:query][:page][:size] ||= @client.per_page || 10

      loop do
        # Fetch page
        response = @client.get(url, params)

        # Handle both array responses and single-item responses
        items = extract_items(response)

        # Break if no items (empty page)
        break if items.empty?

        # Yield each item as resource object
        items.each do |item_data|
          resource = instantiate_resource(item_data)
          block.call(resource)
        end

        # Find next page URL
        next_url = find_next_link(response)
        break unless next_url

        # Update URL for next iteration, clear params (URL contains them)
        url = next_url
        params = {}
      end
    end

    # Extract items from API response
    #
    # Handles both array responses and single-item wrapped responses.
    #
    # @param response [Hash, Array] API response
    # @return [Array] Array of item data hashes
    # @api private
    def extract_items(response)
      if response.is_a?(Array)
        response
      elsif response.is_a?(Hash) && response.key?(:data)
        # Wrapped response: {data: [...]}
        data = response[:data]
        data.is_a?(Array) ? data : [data]
      else
        []
      end
    end

    # Instantiate a resource from API data
    #
    # Calls the resource class's from_api_data method with client and data.
    # Passes through any additional options (like namespace_id).
    #
    # @param data [Hash] Raw API data
    # @return [Resource] Resource instance
    # @api private
    def instantiate_resource(data)
      # Extract any additional options needed for instantiation
      instantiation_options = @options.select { |k, _v| k.to_s.start_with?('_') }
                                      .transform_keys { |k| k.to_s.delete_prefix('_').to_sym }

      @resource_class.from_api_data(@client, data, instantiation_options)
    end

    # Find next page link from response
    #
    # Uses JSON:API pagination format (per OpenAPI spec):
    # response[:links][:next] contains the next page URL
    #
    # @param response [Hash] API response
    # @return [String, nil] Next page URL or nil if no more pages
    # @api private
    def find_next_link(response)
      # JSON:API pagination format - check for links.next in hash
      return nil unless response.is_a?(Hash)

      response.dig(:links, :next)
    end
  end
end
