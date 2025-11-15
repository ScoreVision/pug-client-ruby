# frozen_string_literal: true

require 'pug_client/version'
require 'pug_client/api_version'
require 'pug_client/errors'

# ============================================================================
# NEW ARCHITECTURE: Resource-based OO pattern
# Foundation components for dirty tracking, attribute translation, and pagination
# ============================================================================
require 'pug_client/attribute_translator'
require 'pug_client/tracked_hash'
require 'pug_client/dirty_tracker'
require 'pug_client/patch_generator'
require 'pug_client/resource_enumerator'
require 'pug_client/resource'

# Resource classes (new OO pattern)
require 'pug_client/resources/namespace'
require 'pug_client/resources/video'
require 'pug_client/resources/campaign'
require 'pug_client/resources/live_stream'
require 'pug_client/resources/namespace_client'
require 'pug_client/resources/playlist'
require 'pug_client/resources/simulcast_target'
require 'pug_client/resources/webhook'
# ============================================================================
# END NEW ARCHITECTURE
# ============================================================================

# Core client infrastructure (shared)
require 'pug_client/configurable'
require 'pug_client/default'
require 'pug_client/connection'
require 'pug_client/authentication'

# ============================================================================
# LEGACY: Old client-centric module architecture (FULLY MIGRATED!)
# All legacy modules have been migrated to the new resource-based pattern!
# ============================================================================
# No legacy modules remaining!
# ============================================================================
# END LEGACY
# ============================================================================

require 'pug_client/client'

# Ruby toolkit for the Pug Video API
#
# PugClient provides a Ruby interface for the Pug Video API, offering
# both module-level and instance-level configuration patterns inspired by Octokit.
#
# @see https://github.com/anthropics/pug-client-ruby GitHub Repository
# @see https://staging-api.video.scorevision.com/openapi.json API Specification
#
# @example Module-level configuration (singleton pattern)
#   PugClient.configure do |c|
#     c.client_id = ENV['PUG_CLIENT_ID']
#     c.client_secret = ENV['PUG_CLIENT_SECRET']
#   end
#
#   # Use the configured client
#   namespaces = PugClient.namespaces
#
# @example Instance-level configuration
#   client = PugClient::Client.new(
#     environment: :staging,
#     client_id: 'your_client_id',
#     client_secret: 'your_client_secret'
#   )
#   namespaces = client.namespaces('my-namespace')
#
# @example Switching environments
#   PugClient.use_staging!  # Switch to staging environment
#   PugClient.use_production!  # Switch to production environment
module PugClient
  class << self
    include PugClient::Configurable

    attr_writer :environment

    # Get the current environment
    #
    # @return [Symbol] The current environment (:production or :staging)
    def environment
      @environment ||= :production
    end

    # Set environment to staging and reset configuration
    #
    # @return [PugClient] self
    # @example
    #   PugClient.use_staging!
    #   PugClient.api_endpoint  # => "https://staging-api.video.scorevision.com"
    def use_staging!
      @environment = :staging
      reset!
    end

    # Set environment to production and reset configuration
    #
    # @return [PugClient] self
    # @example
    #   PugClient.use_production!
    #   PugClient.api_endpoint  # => "https://api.video.scorevision.com"
    def use_production!
      @environment = :production
      reset!
    end

    # Get a client instance with the module-level configuration
    #
    # Accepts options that override module-level config.
    # Priority: passed options > module-level config > environment defaults
    #
    # @param options [Hash] Configuration options to override module-level config
    # @option options [Symbol] :environment Environment preset (:production or :staging)
    # @option options [String] :client_id OAuth2 client ID
    # @option options [String] :client_secret OAuth2 client secret
    # @option options [String] :access_token Pre-configured access token
    # @option options [String] :api_endpoint Custom API endpoint URL
    # @option options [Integer] :per_page Default pagination page size
    # @option options [Boolean] :auto_paginate Auto-paginate through all results
    # @return [PugClient::Client] A configured client instance
    # @example
    #   PugClient.configure { |c| c.client_id = 'abc123' }
    #   client = PugClient.client
    # @example Override module config
    #   client = PugClient.client(environment: :staging, per_page: 50)
    def client(options = {})
      merged_options = module_options.merge(options)

      @client = PugClient::Client.new(merged_options)
    end

    # Get the module-level configuration options
    #
    # @return [Hash] Hash of all configuration options and their values
    def module_options
      Hash[PugClient::Configurable.keys.map { |key| [key, instance_variable_get(:"@#{key}")] }]
    end

    # Reset configuration to defaults for current environment
    #
    # @return [PugClient] self
    # @example
    #   PugClient.configure { |c| c.per_page = 100 }
    #   PugClient.reset!
    #   PugClient.per_page  # => 10 (default)
    def reset!
      defaults = case environment
                 when :staging
                   PugClient::DefaultStaging.options
                 else
                   PugClient::DefaultProduction.options
                 end

      PugClient::Configurable.keys.each do |key|
        instance_variable_set(:"@#{key}", defaults[key])
      end
      self
    end

    private

    def respond_to_missing?(method_name, include_private = false)
      client.respond_to?(method_name, include_private)
    end

    # Delegate method calls to the module-level client instance
    #
    # Enables calling API methods directly on the PugClient module:
    # PugClient.namespaces instead of PugClient.client.namespaces
    #
    # @api private
    def method_missing(method_name, *args, &block)
      return client.send(method_name, *args, &block) if client.respond_to?(method_name)

      super
    end
  end
end

PugClient.reset!
