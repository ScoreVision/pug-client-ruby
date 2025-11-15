# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient do
  describe 'module configuration' do
    it 'has a default environment of production' do
      expect(PugClient.environment).to eq(:production)
    end

    describe '.use_staging!' do
      it 'sets the environment to staging' do
        PugClient.use_staging!
        expect(PugClient.environment).to eq(:staging)
      end

      it 'resets configuration to staging defaults' do
        PugClient.use_staging!
        expect(PugClient.api_endpoint).to eq(PugClient::DefaultStaging::API_ENDPOINT)
        expect(PugClient.auth_endpoint).to eq(PugClient::DefaultStaging::AUTH_ENDPOINT)
      end
    end

    describe '.use_production!' do
      it 'sets the environment to production' do
        PugClient.use_staging!
        PugClient.use_production!
        expect(PugClient.environment).to eq(:production)
      end

      it 'resets configuration to production defaults' do
        PugClient.use_production!
        expect(PugClient.api_endpoint).to eq(PugClient::DefaultProduction::API_ENDPOINT)
        expect(PugClient.auth_endpoint).to eq(PugClient::DefaultProduction::AUTH_ENDPOINT)
      end
    end

    describe '.configure' do
      it 'allows setting configuration options' do
        PugClient.configure do |c|
          c.client_id = 'test_client_id'
          c.client_secret = 'test_secret'
          c.per_page = 25
        end

        expect(PugClient.client_id).to eq('test_client_id')
        expect(PugClient.client_secret).to eq('test_secret')
        expect(PugClient.per_page).to eq(25)
      end
    end

    describe '.reset!' do
      it 'resets configuration to environment defaults' do
        PugClient.configure do |c|
          c.client_id = 'test_client_id'
          c.per_page = 25
        end

        PugClient.reset!

        expect(PugClient.client_id).to eq(ENV['PUG_CLIENT_ID'])
        expect(PugClient.per_page).to eq(PugClient::DefaultProduction::PER_PAGE)
      end
    end

    describe '.module_options' do
      it 'returns a hash of current module-level configuration' do
        PugClient.configure do |c|
          c.client_id = 'test_client_id'
          c.per_page = 25
        end

        options = PugClient.module_options
        expect(options[:client_id]).to eq('test_client_id')
        expect(options[:per_page]).to eq(25)
      end
    end
  end

  describe '.client' do
    it 'creates a new client with module-level configuration' do
      PugClient.configure do |c|
        c.namespace = 'test-namespace'
        c.client_id = 'test_client_id'
        c.client_secret = 'test_secret'
      end

      client = PugClient.client
      expect(client).to be_a(PugClient::Client)
      expect(client.options[:namespace]).to eq('test-namespace')
      expect(client.options[:client_id]).to eq('test_client_id')
      expect(client.options[:client_secret]).to eq('test_secret')
    end

    it 'allows overriding module-level configuration' do
      PugClient.configure do |c|
        c.namespace = 'module-namespace'
        c.client_id = 'module_client_id'
        c.per_page = 10
      end

      client = PugClient.client(client_id: 'override_id', per_page: 25)
      expect(client.options[:namespace]).to eq('module-namespace')
      expect(client.options[:client_id]).to eq('override_id')
      expect(client.options[:per_page]).to eq(25)
    end

    it 'creates client with environment defaults when no module config is set' do
      PugClient.reset!
      client = PugClient.client(namespace: 'test-namespace')
      expect(client.options[:api_endpoint]).to eq(PugClient::DefaultProduction::API_ENDPOINT)
    end
  end

  describe 'method delegation' do
    before do
      PugClient.configure do |c|
        c.namespace = 'test-namespace'
      end
    end

    it 'delegates missing methods to the client instance' do
      # PugClient.namespaces should delegate to client.namespaces
      # Now returns ResourceEnumerator instead of Array
      response = PugClient.namespaces
      expect(response).to be_a(PugClient::ResourceEnumerator)
      expect(response.resource_class).to eq(PugClient::Resources::Namespace)
    end
  end
end
