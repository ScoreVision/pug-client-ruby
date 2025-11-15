# frozen_string_literal: true

require 'faraday'
require 'json'

module PugClient
  # HTTP communication and pagination using Faraday
  #
  # This module provides HTTP methods (GET, POST, PATCH, PUT, DELETE) and
  # pagination support for JSON:API formatted responses. It uses Faraday
  # for HTTP communication with automatic JSON encoding/decoding.
  #
  # @example Basic HTTP requests
  #   response = client.get('namespaces')
  #   response = client.post('namespaces', data: { ... })
  #
  # @example Pagination
  #   # Manual pagination (single page)
  #   videos = client.paginate('namespaces/my-ns/videos')
  #
  #   # Auto-pagination (all pages)
  #   client.auto_paginate = true
  #   all_videos = client.paginate('namespaces/my-ns/videos')
  module Connection
    # Simple response wrapper to maintain compatibility with existing code
    #
    # @api private
    class Response
      attr_reader :status, :headers, :body, :data

      def initialize(faraday_response)
        @status = faraday_response.status
        @headers = faraday_response.headers
        @body = faraday_response.body
        @data = parse_body(faraday_response.body)
      end

      private

      def parse_body(body)
        return nil if body.nil? || body.empty?

        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        body
      end
    end

    # Make a GET request
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options
    # @return [Hash] Parsed response data
    def get(url, options = {})
      request(:get, url, options)
    end

    # Make a POST request
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options and body data
    # @return [Hash] Parsed response data
    def post(url, options = {})
      request(:post, url, options)
    end

    # Make a PUT request
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options and body data
    # @return [Hash] Parsed response data
    def put(url, options = {})
      request(:put, url, options)
    end

    # Make a PATCH request
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options and body data
    # @return [Hash] Parsed response data
    def patch(url, options = {})
      request(:patch, url, options)
    end

    # Make a DELETE request
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options
    # @return [Hash] Parsed response data
    def delete(url, options = {})
      request(:delete, url, options)
    end

    # Make a paginated GET request
    #
    # Supports both manual pagination (returns single page) and automatic
    # pagination (follows next links to fetch all pages). Uses JSON:API
    # pagination format with page[size] and page[after] parameters.
    #
    # Returns an array in both cases to match Octokit.rb behavior:
    # - Without auto_paginate: Array of resources from the first page
    # - With auto_paginate: Array of all resources across all pages
    #
    # @param url [String] URL path (relative to api_endpoint)
    # @param options [Hash] Request options
    # @option options [Hash] :query Query parameters including page options
    # @yield [Array] Optional block called for each page
    # @return [Array<Hash>] Array of resources (single page or all pages)
    # @example Manual pagination (first page only)
    #   videos = client.paginate('namespaces/my-ns/videos')
    #   videos.each { |v| puts v[:id] }
    #
    # @example Auto-pagination (all pages)
    #   client.auto_paginate = true
    #   all_videos = client.paginate('namespaces/my-ns/videos')
    #   puts "Total: #{all_videos.length}"
    #
    # @example Custom page size
    #   videos = client.paginate('namespaces/my-ns/videos',
    #     query: { page: { size: 50 } }
    #   )
    def paginate(url, options = {})
      opts = parse_query_and_convenience_headers(url, options.dup)

      # Set up pagination params once, before any requests (like Octokit)
      # When auto_paginate is enabled, use max page size of 100 to minimize API calls
      opts[:query][:page] ||= {}
      opts[:query][:page][:size] ||= (@auto_paginate ? 100 : (@per_page || 10))

      # Make initial request
      @last_response = make_request(:get, url, opts)

      # Extract initial data array
      data = extract_data_array(@last_response.data)

      # Yield first page if block given
      yield(data, @last_response) if block_given?

      # If auto_paginate, fetch remaining pages
      if @auto_paginate
        while (next_url = get_next_page_url(@last_response.data))
          # For subsequent requests, use the full next URL without adding query params
          # Extract just the path from the next URL
          next_path = URI.parse(next_url).request_uri
          @last_response = make_request(:get, next_path, { headers: opts[:headers] })
          page_data = extract_data_array(@last_response.data)

          # Stop if we get an empty page (no more results)
          break if page_data.empty?

          if block_given?
            yield(page_data, @last_response)
          elsif page_data
            data.concat(page_data)
          end
        end
      end

      data
    end

    # Get the last HTTP response
    #
    # Provides access to the Response object from the most recent
    # HTTP request, including status code, headers, and parsed body.
    #
    # @return [Connection::Response] The last HTTP response
    # @example
    #   client.get('namespaces')
    #   client.last_response.status  # => 200
    #   client.last_response.headers  # => {...}
    def last_response
      @last_response
    end

    private

    # Make an HTTP request via Faraday
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :patch, :delete)
    # @param url [String] URL path relative to api_endpoint
    # @param options [Hash] Request options
    # @return [Hash] Parsed response data
    # @api private
    def request(method, url, options = {})
      ensure_authenticated!
      opts = parse_query_and_convenience_headers(url, options.dup)
      @last_response = make_request(method, url, opts)
      @last_response.data
    end

    # Perform the actual HTTP request
    #
    # @param method [Symbol] HTTP method
    # @param url [String] URL path
    # @param options [Hash] Request options with :query, :headers, :data
    # @return [Connection::Response] Wrapped response
    # @api private
    def make_request(method, url, options = {})
      response = connection.send(method) do |req|
        req.url url
        req.params = flatten_params(options[:query]) if options[:query]
        req.headers.update(options[:headers]) if options[:headers]
        req.body = options[:data].to_json if options[:data] && !options[:data].empty?
      end

      # Check for error statuses and raise appropriate exceptions
      handle_error_response(response) if response.status >= 400

      Response.new(response)
    rescue Faraday::Error => e
      raise NetworkError, "HTTP request failed: #{e.message}"
    end

    # Handle HTTP error responses
    #
    # @param response [Faraday::Response] HTTP response with error status
    # @raise [Error] Appropriate error based on status code
    # @api private
    def handle_error_response(response)
      case response.status
      when 404
        # Create a special error that can be caught and converted to ResourceNotFound
        error = NetworkError.new('Resource not found (404)')
        error.instance_variable_set(:@response, response)
        error.define_singleton_method(:response) { @response }
        raise error
      when 401, 403
        raise AuthenticationError, "Authentication failed (#{response.status})"
      when 422
        error = ValidationError.new('Validation error (422)')
        error.instance_variable_set(:@response, response)
        error.define_singleton_method(:response) { @response }
        raise error
      when 400..499
        error = ValidationError.new("Client error (#{response.status})")
        error.instance_variable_set(:@response, response)
        error.define_singleton_method(:response) { @response }
        raise error
      when 500..599
        raise NetworkError, "Server error (#{response.status})"
      else
        raise NetworkError, "HTTP error (#{response.status})"
      end
    end

    # Get or create a Faraday connection for making HTTP requests
    #
    # @return [Faraday::Connection] Configured Faraday connection
    # @api private
    def connection
      @connection ||= Faraday.new(url: api_endpoint, headers: default_headers) do |conn|
        # Add custom middleware if provided
        conn.builder = @middleware if @middleware

        # Use default adapter
        conn.adapter Faraday.default_adapter

        # Apply connection options
        apply_connection_options(conn)
      end
    end

    # Apply connection options to Faraday connection
    #
    # @param conn [Faraday::Connection] Faraday connection
    # @api private
    def apply_connection_options(conn)
      return unless @connection_options

      return unless @connection_options[:request]

      conn.options.timeout = @connection_options[:request][:timeout] if @connection_options[:request][:timeout]
      return unless @connection_options[:request][:open_timeout]

      conn.options.open_timeout = @connection_options[:request][:open_timeout]
    end

    # Get default headers for all requests
    #
    # @return [Hash] Default headers
    # @api private
    def default_headers
      {
        'Accept' => 'application/vnd.api+json',
        'Content-Type' => 'application/vnd.api+json',
        'User-Agent' => "PugClient Ruby Gem #{PugClient::VERSION}"
      }.tap do |headers|
        headers['Authorization'] = "Bearer #{@access_token}" if @access_token
      end
    end

    # Parse request options into query and header components
    #
    # @param url [String] URL for the request (unused but kept for signature compatibility)
    # @param options [Hash, Object] Request options or data
    # @return [Hash] Parsed options with :query, :headers, and :data keys
    # @api private
    def parse_query_and_convenience_headers(_url, options)
      opts = { query: {}, headers: {} }

      if options.is_a?(Hash)
        headers = options.delete(:headers) || {}
        opts[:headers] = headers

        query = options.delete(:query) || {}
        opts[:query] = query
      end
      opts[:data] = options

      opts
    end

    # Flatten nested hash params for query string
    #
    # Converts { page: { size: 10 } } to { 'page[size]' => 10 }
    #
    # @param params [Hash] Nested parameters
    # @param prefix [String, nil] Key prefix for recursion
    # @return [Hash] Flattened parameters
    # @api private
    def flatten_params(params, prefix = nil)
      result = {}

      params.each do |key, value|
        full_key = prefix ? "#{prefix}[#{key}]" : key.to_s

        if value.is_a?(Hash)
          result.merge!(flatten_params(value, full_key))
        else
          result[full_key] = value
        end
      end

      result
    end

    # Extract data array from JSON:API response
    #
    # @param response_data [Hash] Parsed response data
    # @return [Array] Array of resource data
    # @api private
    def extract_data_array(response_data)
      return [] unless response_data

      if response_data[:data].is_a?(Array)
        response_data[:data]
      elsif response_data.is_a?(Array)
        response_data
      else
        []
      end
    end

    # Get next page URL from JSON:API links
    #
    # @param response_data [Hash] Parsed response data
    # @return [String, nil] Next page URL or nil
    # @api private
    def get_next_page_url(response_data)
      return nil unless response_data

      response_data.dig(:links, :next)
    end
  end
end
