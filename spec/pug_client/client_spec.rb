# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Client do
  describe 'initialization' do
    context 'with production environment' do
      it 'uses production defaults' do
        client = PugClient::Client.new(environment: :production, namespace: 'test-namespace')
        expect(client.options[:api_endpoint]).to eq('https://api.video.scorevision.com')
        expect(client.options[:auth_endpoint]).to eq('https://fantagio.auth0.com/oauth/token')
        expect(client.options[:auth_audience]).to eq('https://api.fantag.io/')
      end

      it 'defaults to production when no environment specified' do
        client = PugClient::Client.new(namespace: 'test-namespace')
        expect(client.options[:api_endpoint]).to eq('https://api.video.scorevision.com')
      end
    end

    context 'with staging environment' do
      it 'uses staging defaults' do
        client = PugClient::Client.new(environment: :staging, namespace: 'test-namespace')
        expect(client.options[:api_endpoint]).to eq('https://staging-api.video.scorevision.com')
        expect(client.options[:auth_endpoint]).to eq('https://fantagio-staging.auth0.com/oauth/token')
        expect(client.options[:auth_audience]).to eq('https://staging-api.fantag.io/')
      end
    end

    context 'with unknown environment' do
      it 'raises an ArgumentError' do
        expect do
          PugClient::Client.new(environment: :unknown, namespace: 'test-namespace')
        end.to raise_error(ArgumentError, /Unknown environment: unknown/)
      end
    end

    context 'with custom options' do
      it 'allows overriding environment defaults' do
        client = PugClient::Client.new(
          environment: :production,
          namespace: 'test-namespace',
          client_id: 'custom_id',
          per_page: 50
        )

        expect(client.options[:client_id]).to eq('custom_id')
        expect(client.options[:per_page]).to eq(50)
        expect(client.options[:api_endpoint]).to eq('https://api.video.scorevision.com')
      end

      it 'allows custom endpoints without environment' do
        client = PugClient::Client.new(
          api_endpoint: 'http://localhost:3000',
          auth_endpoint: 'http://localhost:3001/oauth/token',
          auth_audience: 'http://localhost:3000/',
          namespace: 'test-namespace',
          client_id: 'test_id',
          client_secret: 'test_secret'
        )

        expect(client.options[:api_endpoint]).to eq('http://localhost:3000')
        expect(client.options[:auth_endpoint]).to eq('http://localhost:3001/oauth/token')
      end
    end
  end

  describe '#options' do
    it 'returns a hash of current configuration' do
      client = PugClient::Client.new(
        environment: :staging,
        namespace: 'test-namespace',
        client_id: 'test_id',
        per_page: 25
      )

      options = client.options
      expect(options).to be_a(Hash)
      expect(options[:client_id]).to eq('test_id')
      expect(options[:per_page]).to eq(25)
      expect(options[:api_endpoint]).to eq('https://staging-api.video.scorevision.com')
    end

    it 'includes all configurable keys' do
      client = PugClient::Client.new(namespace: 'test-namespace')
      options = client.options
      expect(options.keys).to match_array(PugClient::Configurable.keys)
    end
  end

  describe '#same_options?' do
    let(:client) do
      PugClient::Client.new(
        environment: :production,
        namespace: 'test-namespace',
        client_id: 'test_id',
        per_page: 25
      )
    end

    it 'returns true when options have the same hash' do
      same_opts = client.options.dup
      expect(client.same_options?(same_opts)).to eq(true)
    end

    it 'returns false when options differ' do
      different_opts = client.options.dup
      different_opts[:per_page] = 50
      expect(client.same_options?(different_opts)).to eq(false)
    end
  end

  describe 'module inclusion' do
    let(:client) { PugClient::Client.new(namespace: 'test-namespace') }

    it 'includes Configurable module' do
      expect(client).to respond_to(:api_endpoint)
      expect(client).to respond_to(:client_id)
      expect(client).to respond_to(:configure)
    end

    it 'includes Connection module' do
      expect(client).to respond_to(:get)
      expect(client).to respond_to(:post)
      expect(client).to respond_to(:patch)
      expect(client).to respond_to(:delete)
      expect(client).to respond_to(:paginate)
    end

    it 'includes Authentication module' do
      expect(client).to respond_to(:authenticate!)
      expect(client).to respond_to(:authenticated?)
      expect(client).to respond_to(:token_expired?)
      expect(client).to respond_to(:ensure_authenticated!)
    end

    it 'includes Namespaces module' do
      expect(client).to respond_to(:namespaces)
      expect(client).to respond_to(:create_namespace)
      expect(client).to respond_to(:user_namespaces)
    end

    it 'provides video resource methods' do
      expect(client).to respond_to(:videos)
      expect(client).to respond_to(:video)
      expect(client).to respond_to(:create_video)
    end
  end

  describe 'configuration merging precedence' do
    it 'prioritizes instance options over environment defaults' do
      client = PugClient::Client.new(
        environment: :production,
        namespace: 'test-namespace',
        per_page: 100
      )

      expect(client.options[:per_page]).to eq(100)
      expect(client.options[:api_endpoint]).to eq('https://api.video.scorevision.com')
    end
  end
end
