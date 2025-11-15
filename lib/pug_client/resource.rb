# frozen_string_literal: true

module PugClient
  # Base class for all API resources
  #
  # Provides common functionality for resource objects including:
  # - Attribute storage and access
  # - Dirty tracking and change detection
  # - API format conversion (camelCase <-> snake_case)
  # - JSON Patch generation for updates
  # - Dynamic attribute access via method_missing
  #
  # @example
  #   class Video < Resource
  #     READ_ONLY_ATTRIBUTES = [:id, :created_at, :duration].freeze
  #
  #     def save
  #       # Implementation specific to videos
  #     end
  #   end
  #
  #   video = Video.new(client: client, attributes: {...})
  #   video.metadata[:labels][:status] = 'ready'
  #   video.changed?  # => true
  #   video.save      # Sends JSON Patch to API
  class Resource
    include DirtyTracker

    # Attributes that cannot be modified after creation
    # Subclasses should override this to specify their read-only attributes
    READ_ONLY_ATTRIBUTES = [].freeze

    attr_reader :client, :id

    # Initialize a new resource
    #
    # @param client [Client] The API client
    # @param attributes [Hash] Initial attributes from API or manual creation
    def initialize(client:, attributes: {})
      @client = client
      @current_attributes = {}
      @original_attributes = {}
      load_attributes(attributes)
      clear_dirty!
    end

    # Load attributes from API response
    #
    # Handles JSON:API format with data wrapper, converts camelCase to snake_case,
    # and wraps nested hashes in TrackedHash for dirty tracking.
    #
    # @param data [Hash] API response data
    # @return [void]
    def load_attributes(data)
      # Ensure data is a hash
      data = data.to_h if data.respond_to?(:to_h) && !data.is_a?(Hash)

      # Handle JSON:API formats
      parsed = if data.is_a?(Hash) && data.key?(:data)
                 # Wrapped format: {data: {id: ..., attributes: ...}} or {data: [{...}, {...}]}
                 data_obj = data[:data]

                 # Handle case where data is an array with single element
                 data_obj = data_obj.first if data_obj.is_a?(Array) && data_obj.length == 1

                 # If data_obj is still an array or nil, we have an unexpected format
                 if data_obj.nil? || data_obj.is_a?(Array)
                   {}
                 else
                   attrs = AttributeTranslator.from_api(data_obj[:attributes] || {})
                   attrs.merge(id: data_obj[:id], type: data_obj[:type])
                 end
               elsif data.is_a?(Hash) && data.key?(:id) && data.key?(:attributes)
                 # Unwrapped JSON:API object: {id: ..., type: ..., attributes: {...}}
                 # This happens when individual items are extracted from a list
                 attrs = AttributeTranslator.from_api(data[:attributes] || {})
                 attrs.merge(id: data[:id], type: data[:type])
               else
                 # Assume data is already a flat hash of attributes (already translated)
                 AttributeTranslator.from_api(data)
               end

      # Wrap hashes in TrackedHash for dirty tracking
      parsed.each do |key, value|
        parsed[key] = wrap_value(value)
      end

      @current_attributes = parsed
      @original_attributes = deep_dup(@current_attributes)
      @id = @current_attributes[:id]
    end

    # Dynamic attribute getter
    #
    # Allows accessing attributes via method calls: video.duration
    #
    # @param method_name [Symbol] Method name
    # @param args [Array] Method arguments
    # @return [Object] Attribute value
    def method_missing(method_name, *args, &block)
      method_str = method_name.to_s

      if method_str.end_with?('=')
        # Setter: video.status = 'ready'
        attr_name = method_str.chomp('=').to_sym
        validate_writable!(attr_name)
        mark_dirty!
        @current_attributes[attr_name] = wrap_value(args.first)
      elsif @current_attributes.key?(method_name)
        # Getter: video.status
        @current_attributes[method_name]
      else
        super
      end
    end

    # Check if attribute accessor method exists
    #
    # @param method_name [Symbol] Method name
    # @param include_private [Boolean] Include private methods
    # @return [Boolean] true if method responds
    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      return true if method_str.end_with?('=')

      @current_attributes.key?(method_name) || super
    end

    # Save changes to API (must be implemented by subclass)
    #
    # @return [Boolean] true if saved successfully
    # @raise [NotImplementedError] if not implemented by subclass
    def save
      raise NotImplementedError, "#{self.class} must implement #save"
    end

    # Reload resource from API (must be implemented by subclass)
    #
    # @return [self]
    # @raise [NotImplementedError] if not implemented by subclass
    def reload
      raise NotImplementedError, "#{self.class} must implement #reload"
    end

    # Delete resource from API (must be implemented by subclass)
    #
    # @return [Boolean] true if deleted successfully
    # @raise [NotImplementedError] if not implemented by subclass
    def delete
      raise NotImplementedError, "#{self.class} must implement #delete"
    end

    # Generate JSON Patch operations from tracked changes
    #
    # @return [Array<Hash>] Array of RFC 6902 JSON Patch operations
    def generate_patch_operations
      return [] unless changed?

      PatchGenerator.generate(changes)
    end

    # Freeze resource after deletion to prevent further modifications
    #
    # @return [void]
    def freeze_resource!
      @current_attributes.freeze
      @original_attributes.freeze
      freeze
    end

    # Get all current attributes as a hash
    #
    # @return [Hash] Current attributes
    def attributes
      @current_attributes.dup
    end

    # Inspect resource for debugging
    #
    # @return [String] Human-readable representation
    def inspect
      "#<#{self.class.name} id=#{@id.inspect} changed=#{changed?}>"
    end

    private

    # Wrap hashes and arrays in TrackedHash/tracked arrays
    #
    # @param value [Object] Value to wrap
    # @return [Object] Wrapped value
    def wrap_value(value)
      case value
      when Hash
        # Don't re-wrap if already a TrackedHash
        return value if value.is_a?(TrackedHash)

        TrackedHash.new(value, parent_resource: self)
      when Array
        value.map { |v| wrap_value(v) }
      else
        value
      end
    end

    # Deep duplicate an object
    #
    # @param object [Object] Object to duplicate
    # @return [Object] Duplicated object
    def deep_dup(object)
      case object
      when Hash
        object.transform_values { |v| deep_dup(v) }
      when Array
        object.map { |e| deep_dup(e) }
      when TrackedHash
        # Convert TrackedHash to regular hash for storage
        deep_dup(object.to_h)
      else
        # Try to dup, but some objects can't be duplicated (nil, true, false, numbers, symbols)
        begin
          object.dup
        rescue TypeError
          object
        end
      end
    end

    # Validate that an attribute is writable
    #
    # @param attr_name [Symbol] Attribute name
    # @raise [ValidationError] if attribute is read-only
    def validate_writable!(attr_name)
      return unless self.class::READ_ONLY_ATTRIBUTES.include?(attr_name)

      raise ValidationError, "Cannot modify read-only attribute: #{attr_name}"
    end
  end
end
