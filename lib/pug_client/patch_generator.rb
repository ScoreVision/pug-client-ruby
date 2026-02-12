# frozen_string_literal: true

module PugClient
  # Generates RFC 6902 JSON Patch operations from dirty tracking changes
  #
  # Converts the change list from DirtyTracker into JSON Patch operations
  # that can be sent to the API for PATCH requests.
  #
  # @example
  #   changes = [
  #     {type: :replace, path: [:metadata, :labels, :status], new_value: 'ready'}
  #   ]
  #   PatchGenerator.generate(changes)
  #   # => [{op: 'replace', path: '/metadata/labels/status', value: 'ready'}]
  module PatchGenerator
    # Generate JSON Patch operations from changes
    #
    # @param changes [Array<Hash>] List of changes from DirtyTracker
    # @return [Array<Hash>] List of JSON Patch operations
    # @example
    #   changes = [
    #     {type: :add, path: [:metadata, :labels, :new_key], value: 'value'},
    #     {type: :replace, path: [:status], old_value: 'old', new_value: 'new'},
    #     {type: :remove, path: [:metadata, :labels, :old_key]}
    #   ]
    #   patches = PatchGenerator.generate(changes)
    def self.generate(changes)
      changes.map do |change|
        case change[:type]
        when :add
          {
            op: 'add',
            path: json_pointer(change[:path]),
            value: convert_value(change[:value])
          }
        when :remove
          {
            op: 'remove',
            path: json_pointer(change[:path])
          }
        when :replace
          {
            op: 'replace',
            path: json_pointer(change[:path]),
            value: convert_value(change[:new_value])
          }
        end
      end
    end

    # Convert attribute path to JSON Pointer
    #
    # Keeps snake_case paths as-is because the API applies JSON Patch operations
    # against raw Ecto structs with snake_case keys.
    # Note: JSON Patch paths do NOT include /attributes prefix (unlike JSON:API GET responses).
    #
    # @param path_array [Array<Symbol>] Path as array of symbols
    # @return [String] JSON Pointer string
    # @example
    #   json_pointer([:metadata, :labels, :status])
    #   # => "/metadata/labels/status"
    # @api private
    def self.json_pointer(path_array)
      "/#{path_array.map(&:to_s).join('/')}"
    end

    # Convert value to API format
    #
    # Converts TrackedHash to regular Hash but preserves snake_case keys,
    # since the API applies patches against raw Ecto structs.
    #
    # @param value [Object] Value to convert
    # @return [Object] Value with TrackedHash converted to plain Hash
    # @api private
    def self.convert_value(value)
      # Convert TrackedHash to regular Hash
      value = value.to_h if value.is_a?(TrackedHash)

      value
    end

    private_class_method :json_pointer, :convert_value
  end
end
