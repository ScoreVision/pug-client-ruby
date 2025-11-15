# frozen_string_literal: true

module PugClient
  # Mixin module for tracking attribute changes in resources
  #
  # This module provides dirty tracking functionality by comparing
  # @original_attributes with @current_attributes and generating
  # a list of changes with their paths.
  #
  # @example
  #   class Video
  #     include DirtyTracker
  #   end
  #
  #   video.changed?  # => false
  #   video.metadata[:labels][:status] = 'ready'
  #   video.changed?  # => true
  #   video.changes   # => [{type: :replace, path: [:metadata, :labels, :status], ...}]
  module DirtyTracker
    # Check if the resource has unsaved changes
    #
    # @return [Boolean] true if there are unsaved changes
    def changed?
      @dirty || false
    end

    # Mark the resource as having unsaved changes
    #
    # This is called by TrackedHash when nested attributes are modified.
    #
    # @return [void]
    # @raise [ResourceFrozenError] if the resource is frozen
    def mark_dirty!
      raise ResourceFrozenError, 'Cannot modify frozen resource' if frozen?

      @dirty = true
    end

    # Clear the dirty flag
    #
    # Should be called after successfully saving changes.
    #
    # @return [void]
    def clear_dirty!
      @dirty = false
    end

    # Get list of changes with paths and values
    #
    # Returns an array of change hashes, each containing:
    # - type: :add, :remove, or :replace
    # - path: Array of keys leading to changed value
    # - value: New value (for :add operations)
    # - old_value, new_value: Values (for :replace operations)
    #
    # @return [Array<Hash>] List of changes
    # @example
    #   video.changes
    #   # => [
    #   #   {type: :replace, path: [:metadata, :labels, :status], old_value: 'processing', new_value: 'ready'},
    #   #   {type: :add, path: [:metadata, :labels, :new_key], value: 'value'}
    #   # ]
    def changes
      return [] unless @original_attributes && @current_attributes

      find_differences(@original_attributes, @current_attributes)
    end

    private

    # Recursively find differences between two hashes
    #
    # @param original [Hash] Original hash
    # @param current [Hash] Current hash
    # @param path [Array] Current path in the hash hierarchy
    # @return [Array<Hash>] List of differences
    # @api private
    def find_differences(original, current, path = [])
      differences = []

      # Handle TrackedHash (treat as regular hash)
      original = original.to_h if original.is_a?(TrackedHash)
      current = current.to_h if current.is_a?(TrackedHash)

      # Added keys
      (current.keys - original.keys).each do |key|
        differences << {
          type: :add,
          path: path + [key],
          value: current[key]
        }
      end

      # Removed keys
      (original.keys - current.keys).each do |key|
        differences << {
          type: :remove,
          path: path + [key]
        }
      end

      # Changed values
      (original.keys & current.keys).each do |key|
        orig_val = original[key]
        curr_val = current[key]

        # Skip if values are equal
        next if values_equal?(orig_val, curr_val)

        # Recursively check nested hashes
        if hash_like?(orig_val) && hash_like?(curr_val)
          differences += find_differences(orig_val, curr_val, path + [key])
        else
          # Value changed (not a nested hash or types differ)
          differences << {
            type: :replace,
            path: path + [key],
            old_value: orig_val,
            new_value: curr_val
          }
        end
      end

      differences
    end

    # Check if two values are equal
    #
    # Handles TrackedHash comparison by converting to regular hash.
    #
    # @param val1 [Object] First value
    # @param val2 [Object] Second value
    # @return [Boolean] true if values are equal
    # @api private
    def values_equal?(val1, val2)
      # Convert TrackedHash to regular hash for comparison
      val1 = val1.to_h if val1.is_a?(TrackedHash)
      val2 = val2.to_h if val2.is_a?(TrackedHash)

      val1 == val2
    end

    # Check if a value is hash-like (Hash or TrackedHash)
    #
    # @param value [Object] Value to check
    # @return [Boolean] true if value is hash-like
    # @api private
    def hash_like?(value)
      value.is_a?(Hash) || value.is_a?(TrackedHash)
    end
  end
end
