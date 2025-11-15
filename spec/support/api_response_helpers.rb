# frozen_string_literal: true

# Helpers for building JSON:API formatted responses in tests
#
# This module provides utility methods to construct JSON:API compliant
# response structures, reducing duplication across test files.
#
# Usage:
#   RSpec.describe SomeSpec do
#     it 'handles API response' do
#       response = build_api_response(
#         type: 'videos',
#         id: 'video-123',
#         attributes: { 'startedAt' => '2024-01-01T00:00:00Z' }
#       )
#       # => { data: { id: 'video-123', type: 'videos', attributes: {...} } }
#     end
#   end

module ApiResponseHelpers
  # Build a single JSON:API resource response
  #
  # @param type [String] Resource type (e.g., 'videos', 'namespaces')
  # @param id [String] Resource identifier
  # @param attributes [Hash] Resource attributes in API format (camelCase keys)
  # @param relationships [Hash] Optional relationships
  # @return [Hash] JSON:API formatted response
  #
  # @example Simple response
  #   build_api_response(type: 'videos', id: 'v123', attributes: { 'duration' => 5000 })
  #   # => { data: { id: 'v123', type: 'videos', attributes: { 'duration' => 5000 } } }
  def build_api_response(type:, id:, attributes: {}, relationships: nil)
    data = {
      id: id,
      type: type,
      attributes: attributes
    }

    data[:relationships] = relationships if relationships

    { data: data }
  end

  # Build a collection JSON:API response
  #
  # @param type [String] Resource type
  # @param items [Array<Hash>] Array of items, each with :id and :attributes keys
  # @param links [Hash] Optional pagination links
  # @return [Hash] JSON:API formatted collection response
  #
  # @example Collection response
  #   build_api_collection(
  #     type: 'videos',
  #     items: [
  #       { id: 'v1', attributes: { 'duration' => 5000 } },
  #       { id: 'v2', attributes: { 'duration' => 3000 } }
  #     ],
  #     links: { next: 'https://api.example.com/videos?page[after]=cursor' }
  #   )
  def build_api_collection(type:, items: [], links: nil)
    response = {
      data: items.map do |item|
        {
          id: item[:id],
          type: type,
          attributes: item[:attributes] || {},
          relationships: item[:relationships]
        }.compact
      end
    }

    response[:links] = links if links

    response
  end

  # Build common metadata timestamps
  #
  # @param created_at [String] ISO8601 timestamp (default: 2024-01-01T00:00:00Z)
  # @param updated_at [String] ISO8601 timestamp (default: created_at value)
  # @return [Hash] Metadata hash with camelCase keys
  #
  # @example
  #   build_metadata_timestamps
  #   # => { 'createdAt' => '2024-01-01T00:00:00Z', 'updatedAt' => '2024-01-01T00:00:00Z' }
  def build_metadata_timestamps(created_at: '2024-01-01T00:00:00Z', updated_at: nil)
    {
      'createdAt' => created_at,
      'updatedAt' => updated_at || created_at
    }
  end

  # Build standard metadata object
  #
  # @param namespace [String] Namespace identifier (default: 'test-namespace')
  # @param name [String] Optional resource name
  # @param labels [Hash] Optional labels
  # @param annotations [Hash] Optional annotations
  # @return [Hash] Metadata hash in API format
  #
  # @example
  #   build_metadata(name: 'My Video', labels: { type: 'highlight' })
  def build_metadata(namespace: 'test-namespace', name: nil, labels: {}, annotations: {})
    metadata = {
      'namespace' => namespace,
      **build_metadata_timestamps
    }

    metadata['name'] = name if name
    metadata['labels'] = labels unless labels.empty?
    metadata['annotations'] = annotations unless annotations.empty?

    metadata
  end
end

# Include helpers in all RSpec tests
RSpec.configure do |config|
  config.include ApiResponseHelpers
end
