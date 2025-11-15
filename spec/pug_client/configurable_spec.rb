# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Configurable do
  let(:test_class) do
    Class.new do
      include PugClient::Configurable
    end
  end

  let(:instance) { test_class.new }

  describe '.keys' do
    it 'returns all configurable keys' do
      expected_keys = %i[
        api_endpoint
        namespace
        client_id
        client_secret
        connection_options
        per_page
        auto_paginate
        auth_endpoint
        auth_audience
        auth_grant_type
      ]

      expect(PugClient::Configurable.keys).to match_array(expected_keys)
    end
  end

  describe 'attribute accessors' do
    it 'provides accessors for api_endpoint' do
      instance.api_endpoint = 'https://test.example.com'
      expect(instance.api_endpoint).to eq('https://test.example.com')
    end

    it 'provides accessors for client_id' do
      instance.client_id = 'test_client_id'
      expect(instance.client_id).to eq('test_client_id')
    end

    it 'provides accessors for client_secret' do
      instance.client_secret = 'test_secret'
      expect(instance.client_secret).to eq('test_secret')
    end

    it 'provides accessors for connection_options' do
      options = { timeout: 30 }
      instance.connection_options = options
      expect(instance.connection_options).to eq(options)
    end

    it 'provides accessors for per_page' do
      instance.per_page = 50
      expect(instance.per_page).to eq(50)
    end

    it 'provides accessors for auto_paginate' do
      instance.auto_paginate = true
      expect(instance.auto_paginate).to eq(true)
    end

    it 'provides accessors for auth_endpoint' do
      instance.auth_endpoint = 'https://auth.example.com/oauth/token'
      expect(instance.auth_endpoint).to eq('https://auth.example.com/oauth/token')
    end

    it 'provides accessors for auth_audience' do
      instance.auth_audience = 'https://api.example.com/'
      expect(instance.auth_audience).to eq('https://api.example.com/')
    end

    it 'provides accessors for auth_grant_type' do
      instance.auth_grant_type = 'client_credentials'
      expect(instance.auth_grant_type).to eq('client_credentials')
    end
  end

  describe '#configure' do
    it 'yields self to configuration block' do
      instance.configure do |config|
        config.client_id = 'configured_id'
        config.per_page = 100
      end

      expect(instance.client_id).to eq('configured_id')
      expect(instance.per_page).to eq(100)
    end

    it 'yields the configuration block' do
      instance.configure do |config|
        config.client_id = 'test'
      end

      expect(instance.client_id).to eq('test')
    end
  end
end
