# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::NamespaceClient do
  let(:client) { PugClient::Client.new(namespace: 'test-namespace', client_id: 'test_id', client_secret: 'test_secret') }
  let(:namespace_id) { 'test-namespace' }
  let(:client_id) { 'new-client-id-123' }
  let(:client_secret) { 'new-client-secret-456' }

  describe '.create' do
    it 'raises FeatureNotSupportedError' do
      expect do
        described_class.create(client, namespace_id)
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /Namespace client creation is not supported/
      )
    end

    it 'raises FeatureNotSupportedError with options' do
      expect do
        described_class.create(
          client,
          namespace_id,
          metadata: { labels: { env: 'production' } }
        )
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /intentionally excluded/
      )
    end

    it 'does not make API calls' do
      expect(client).not_to receive(:post)

      expect do
        described_class.create(client, namespace_id)
      end.to raise_error(PugClient::FeatureNotSupportedError)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API response data' do
      api_data = {
        data: {
          id: client_id,
          type: 'clients',
          attributes: {
            'secret' => client_secret,
            'createdAt' => '2024-01-01T00:00:00Z'
          }
        }
      }

      namespace_client = described_class.from_api_data(
        client,
        api_data,
        _namespace_id: namespace_id
      )

      expect(namespace_client).to be_a(described_class)
      expect(namespace_client.id).to eq(client_id)
      expect(namespace_client.secret).to eq(client_secret)
      expect(namespace_client.namespace_id).to eq(namespace_id)
    end
  end

  describe '#save' do
    let(:namespace_client) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )
    end

    it 'raises NotImplementedError' do
      expect do
        namespace_client.save
      end.to raise_error(NotImplementedError, /cannot be updated/)
    end
  end

  describe '#reload' do
    let(:namespace_client) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )
    end

    it 'raises NotImplementedError' do
      expect do
        namespace_client.reload
      end.to raise_error(NotImplementedError, /cannot be retrieved/)
    end
  end

  describe '#delete' do
    let(:namespace_client) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )
    end

    it 'raises NotImplementedError' do
      expect do
        namespace_client.delete
      end.to raise_error(NotImplementedError, /cannot be deleted/)
    end
  end

  describe '#namespace' do
    let(:namespace_client) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )
    end

    it 'fetches and caches namespace' do
      namespace_data = { id: namespace_id, attributes: {} }

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .once
        .and_return(PugClient::Resources::Namespace.new(
                      client: client,
                      attributes: namespace_data
                    ))

      namespace1 = namespace_client.namespace
      namespace2 = namespace_client.namespace

      expect(namespace1).to be_a(PugClient::Resources::Namespace)
      expect(namespace2).to eq(namespace1)
    end
  end

  describe '#secret_available?' do
    it 'returns true when secret is present' do
      namespace_client = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )

      expect(namespace_client.secret_available?).to be true
    end

    it 'returns false when secret is nil' do
      namespace_client = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: nil }
      )

      expect(namespace_client.secret_available?).to be false
    end

    it 'returns false when secret is not in attributes' do
      namespace_client = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id }
      )

      expect(namespace_client.secret_available?).to be false
    end
  end

  describe 'read-only attributes' do
    let(:namespace_client) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: client_id,
          secret: client_secret,
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-02T00:00:00Z'
        }
      )
    end

    it 'prevents modification of id' do
      expect do
        namespace_client.id = 'new-id'
      end.to raise_error(PugClient::ValidationError, /read-only.*id/i)
    end

    it 'prevents modification of secret' do
      expect do
        namespace_client.secret = 'new-secret'
      end.to raise_error(PugClient::ValidationError, /read-only.*secret/i)
    end

    it 'prevents modification of created_at' do
      expect do
        namespace_client.created_at = '2024-02-01T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /read-only.*created_at/i)
    end

    it 'prevents modification of updated_at' do
      expect do
        namespace_client.updated_at = '2024-02-01T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /read-only.*updated_at/i)
    end

    it 'allows reading read-only attributes' do
      expect(namespace_client.id).to eq(client_id)
      expect(namespace_client.secret).to eq(client_secret)
      expect(namespace_client.created_at).to eq('2024-01-01T00:00:00Z')
      expect(namespace_client.updated_at).to eq('2024-01-02T00:00:00Z')
    end
  end

  describe '#inspect' do
    it 'shows secret as available when present' do
      namespace_client = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id, secret: client_secret }
      )

      expect(namespace_client.inspect).to include('NamespaceClient')
      expect(namespace_client.inspect).to include(client_id)
      expect(namespace_client.inspect).to include('secret=<available>')
      expect(namespace_client.inspect).to include(namespace_id)
    end

    it 'shows secret as unavailable when not present' do
      namespace_client = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: client_id }
      )

      expect(namespace_client.inspect).to include('secret=<unavailable>')
    end
  end
end
