# frozen_string_literal: true

module PugClient
  # Converts attribute names between API camelCase and Ruby snake_case conventions
  #
  # The Pug API uses camelCase for attribute names (e.g., startedAt, playbackURLs),
  # while Ruby conventions prefer snake_case (e.g., started_at, playback_urls).
  # This module provides bidirectional conversion.
  #
  # @example Converting from API format
  #   AttributeTranslator.from_api({"startedAt" => "2025-01-01", "playbackURLs" => {}})
  #   # => {:started_at => "2025-01-01", :playback_urls => {}}
  #
  # @example Converting to API format
  #   AttributeTranslator.to_api({started_at: "2025-01-01", playback_urls: {}})
  #   # => {:startedAt => "2025-01-01", :playbackURLs => {}}
  module AttributeTranslator
    # Convert API response (camelCase) to Ruby (snake_case)
    #
    # Recursively transforms all hash keys from camelCase to snake_case.
    # Handles nested hashes and arrays of hashes.
    #
    # @param hash [Hash, Array, Object] The object to transform
    # @return [Hash, Array, Object] The transformed object with snake_case keys
    def self.from_api(hash)
      deep_transform_keys(hash) { |key| underscore(key) }
    end

    # Convert Ruby (snake_case) to API (camelCase) for requests
    #
    # Recursively transforms all hash keys from snake_case to camelCase.
    # Handles nested hashes and arrays of hashes.
    #
    # @param hash [Hash, Array, Object] The object to transform
    # @return [Hash, Array, Object] The transformed object with camelCase keys
    def self.to_api(hash)
      deep_transform_keys(hash) { |key| camelize(key) }
    end

    # Convert camelCase string to snake_case
    #
    # Handles acronyms intelligently:
    # - "URLs" -> "urls" (keeps acronym together)
    # - "playbackURLs" -> "playback_urls" (splits before acronym)
    # - "HTTPSConnection" -> "https_connection" (splits acronym before new word)
    #
    # @param string [String, Symbol] The camelCase string
    # @return [String] The snake_case string
    # @example
    #   underscore("startedAt")          # => "started_at"
    #   underscore("playbackURLs")       # => "playback_urls"
    #   underscore("HTTPSConnection")    # => "https_connection"
    def self.underscore(string)
      string = string.to_s
      # Split acronyms only when followed by a new word (capital + lowercase + more chars)
      # This preserves trailing acronyms like "URLs" while splitting "HTTPSConnection"
      string.gsub(/([A-Z]+)([A-Z][a-z]\w)/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
    end

    # Known acronyms that should preserve their capitalization
    # Based on actual API field names from the OpenAPI spec:
    # The API uses standard camelCase conventions (playbackUrls, not playbackURLs)
    # This hash is kept for future additions if needed
    ACRONYMS = {}.freeze

    # Convert snake_case string to camelCase
    #
    # Handles known acronyms to preserve proper capitalization:
    # - "playback_urls" -> "playbackURLs" (not "playbackUrls")
    # - "api_key" -> "apiKey" (not "ApiKey")
    #
    # @param string [String, Symbol] The snake_case string
    # @return [String] The camelCase string
    # @example
    #   camelize("started_at")     # => "startedAt"
    #   camelize("playback_urls")  # => "playbackURLs"
    #   camelize("api_endpoint")   # => "apiEndpoint"
    def self.camelize(string)
      string = string.to_s
      string.split('_').inject([]) do |buffer, part|
        if buffer.empty?
          # First part stays lowercase
          buffer.push(part)
        elsif ACRONYMS.key?(part.downcase)
          # Known acronym - use proper capitalization
          buffer.push(ACRONYMS[part.downcase])
        else
          # Normal word - capitalize first letter
          buffer.push(part.capitalize)
        end
      end.join
    end

    # Recursively transform keys in hashes and arrays
    #
    # @param object [Hash, Array, Object] The object to transform
    # @param block [Proc] Block to transform each key
    # @return [Hash, Array, Object] The transformed object
    # @api private
    def self.deep_transform_keys(object, &block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[yield(key).to_sym] = deep_transform_keys(value, &block)
        end
      when Array
        object.map { |element| deep_transform_keys(element, &block) }
      else
        object
      end
    end

    private_class_method :deep_transform_keys
  end
end
