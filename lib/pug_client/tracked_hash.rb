# frozen_string_literal: true

module PugClient
  # A Hash subclass that tracks modifications and notifies parent resource
  #
  # This enables dirty tracking for nested hash attributes. When any value
  # in the hash is modified, it marks the parent resource as dirty.
  #
  # @example
  #   video.metadata[:labels][:status] = 'ready'  # Marks video as dirty
  #   video.metadata[:labels].delete(:old_key)     # Also marks video as dirty
  class TrackedHash < Hash
    attr_accessor :parent_resource

    # Initialize a new TrackedHash
    #
    # @param hash [Hash] Initial hash contents
    # @param parent_resource [Resource] The resource that owns this hash
    def initialize(hash = {}, parent_resource: nil)
      @parent_resource = parent_resource
      @initializing = true
      super()
      hash.each { |k, v| self[k] = v }
      @initializing = false
    end

    # Set a value and mark parent as dirty
    #
    # @param key [Symbol, String] The key
    # @param value [Object] The value
    # @return [Object] The value
    def []=(key, value)
      @parent_resource&.mark_dirty! unless @initializing
      super(key, wrap_value(value))
    end

    # Merge another hash and mark parent as dirty
    #
    # @param other_hash [Hash] Hash to merge
    # @return [TrackedHash] self
    def merge!(other_hash)
      @parent_resource&.mark_dirty!
      other_hash.each { |k, v| self[k] = v }
      self
    end

    # Delete a key and mark parent as dirty
    #
    # @param key [Symbol, String] The key to delete
    # @return [Object] The deleted value
    def delete(key)
      @parent_resource&.mark_dirty!
      super
    end

    # Update hash contents and mark parent as dirty
    #
    # @param other_hash [Hash] Hash to update from
    # @return [TrackedHash] self
    def update(other_hash)
      @parent_resource&.mark_dirty!
      other_hash.each { |k, v| self[k] = v }
      self
    end

    # Store a value and mark parent as dirty (alias for []=)
    #
    # @param key [Symbol, String] The key
    # @param value [Object] The value
    # @return [Object] The value
    def store(key, value)
      self[key] = value
    end

    # Clear all contents and mark parent as dirty
    #
    # @return [TrackedHash] self
    def clear
      @parent_resource&.mark_dirty!
      super
    end

    # Replace contents and mark parent as dirty
    #
    # @param other_hash [Hash] Hash to replace with
    # @return [TrackedHash] self
    def replace(other_hash)
      @parent_resource&.mark_dirty!
      super
      self
    end

    private

    # Wrap nested hashes and arrays in TrackedHash
    #
    # @param value [Object] Value to wrap
    # @return [Object] Wrapped value
    def wrap_value(value)
      case value
      when Hash
        # Don't wrap if already a TrackedHash
        return value if value.is_a?(TrackedHash)

        TrackedHash.new(value, parent_resource: @parent_resource)
      when Array
        value.map { |v| wrap_value(v) }
      else
        value
      end
    end
  end
end
