# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::Webhook do
  include_context 'resource spec client'

  let(:webhook_id) { 'webhook-123' }
  let(:webhook_url) { 'https://my.endpoint.com/webhooks' }
  let(:actions) { ['video.ready', 'livestream.published'] }

  let(:api_response) do
    build_api_response(
      type: 'webhooks',
      id: webhook_id,
      attributes: {
        'url' => webhook_url,
        'actions' => actions,
        **build_metadata_timestamps,
        'metadata' => {
          'labels' => { 'environment' => 'production' }
        }
      }
    )
  end

  describe '.find' do
    it 'fetches a webhook by ID' do
      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/webhooks/#{webhook_id}", {})
        .and_return(api_response)

      webhook = described_class.find(client, namespace_id, webhook_id)

      expect(webhook).to be_a(described_class)
      expect(webhook.id).to eq(webhook_id)
      expect(webhook.namespace_id).to eq(namespace_id)
      expect(webhook.url).to eq(webhook_url)
      expect(webhook.actions).to eq(actions)
    end

    it 'raises ResourceNotFound when webhook does not exist' do
      stub_404_error(client, :get, "namespaces/#{namespace_id}/webhooks/#{webhook_id}")

      expect do
        described_class.find(client, namespace_id, webhook_id)
      end.to raise_error(PugClient::ResourceNotFound, /Webhook.*#{webhook_id}/)
    end

    it 'raises NetworkError for other errors' do
      stub_network_error(client, :get, "namespaces/#{namespace_id}/webhooks/#{webhook_id}",
                         message: 'Connection failed')

      expect do
        described_class.find(client, namespace_id, webhook_id)
      end.to raise_error(PugClient::NetworkError, /Connection failed/)
    end
  end

  describe '.all' do
    it 'returns a ResourceEnumerator' do
      enumerator = described_class.all(client, namespace_id)

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
    end

    it 'passes namespace_id in options' do
      expect(PugClient::ResourceEnumerator).to receive(:new).with(
        hash_including(
          client: client,
          base_url: "namespaces/#{namespace_id}/webhooks",
          resource_class: described_class,
          options: hash_including(_namespace_id: namespace_id)
        )
      )

      described_class.all(client, namespace_id)
    end
  end

  describe '.create' do
    it 'creates a new webhook with URL and actions' do
      expected_body = {
        data: {
          type: 'webhooks',
          attributes: {
            url: webhook_url,
            actions: actions
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/webhooks", expected_body)
        .and_return(api_response)

      webhook = described_class.create(client, namespace_id, webhook_url, actions)

      expect(webhook).to be_a(described_class)
      expect(webhook.id).to eq(webhook_id)
      expect(webhook.namespace_id).to eq(namespace_id)
      expect(webhook.url).to eq(webhook_url)
      expect(webhook.actions).to eq(actions)
    end

    it 'creates a webhook with metadata' do
      metadata = { labels: { environment: 'production', service: 'api' } }

      expected_body = {
        data: {
          type: 'webhooks',
          attributes: {
            url: webhook_url,
            actions: actions,
            metadata: metadata
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/webhooks", expected_body)
        .and_return(api_response)

      webhook = described_class.create(client, namespace_id, webhook_url, actions, metadata: metadata)

      expect(webhook).to be_a(described_class)
      expect(webhook.metadata).to eq(labels: { environment: 'production' })
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :post, "namespaces/#{namespace_id}/webhooks", message: 'API error')

      expect do
        described_class.create(client, namespace_id, webhook_url, actions)
      end.to raise_error(PugClient::NetworkError, /API error/)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API data with namespace_id' do
      webhook = described_class.from_api_data(client, api_response, _namespace_id: namespace_id)

      expect(webhook).to be_a(described_class)
      expect(webhook.id).to eq(webhook_id)
      expect(webhook.namespace_id).to eq(namespace_id)
    end
  end

  describe '#save' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'does nothing if no changes' do
      expect(client).not_to receive(:patch)
      expect(webhook.save).to be true
    end

    it 'sends JSON Patch operations for changes' do
      webhook.url = 'https://new.endpoint.com/webhooks'

      operations = [
        {
          op: 'replace',
          path: '/url',
          value: 'https://new.endpoint.com/webhooks'
        }
      ]

      expect(client).to receive(:patch)
        .with("namespaces/#{namespace_id}/webhooks/#{webhook_id}", { data: operations })
        .and_return(api_response)

      expect(webhook.save).to be true
      expect(webhook.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      webhook.url = 'https://new.endpoint.com/webhooks'

      stub_network_error(client, :patch, "namespaces/#{namespace_id}/webhooks/#{webhook_id}", message: 'API error')

      expect do
        webhook.save
      end.to raise_error(PugClient::NetworkError, /API error/)
    end
  end

  describe '#reload' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'reloads webhook from API' do
      updated_response = api_response.dup
      updated_response[:data][:attributes]['url'] = 'https://new.endpoint.com/webhooks'

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/webhooks/#{webhook_id}")
        .and_return(updated_response)

      result = webhook.reload

      expect(result).to eq(webhook)
      expect(webhook.url).to eq('https://new.endpoint.com/webhooks')
      expect(webhook.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :get, message: 'Connection error')

      expect do
        webhook.reload
      end.to raise_error(PugClient::NetworkError, /Connection error/)
    end
  end

  describe '#delete' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'deletes the webhook' do
      expect(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/webhooks/#{webhook_id}")

      expect(webhook.delete).to be true
      expect(webhook).to be_frozen
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :delete, message: 'Delete failed')

      expect do
        webhook.delete
      end.to raise_error(PugClient::NetworkError, /Delete failed/)
    end
  end

  describe '#namespace' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'fetches the parent namespace' do
      namespace = instance_double(PugClient::Resources::Namespace, id: namespace_id)

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .and_return(namespace)

      expect(webhook.namespace).to eq(namespace)
    end

    it 'caches the namespace' do
      namespace = instance_double(PugClient::Resources::Namespace, id: namespace_id)

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .once
        .and_return(namespace)

      webhook.namespace
      webhook.namespace # Second call should use cached value
    end
  end

  describe '#url' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'returns the webhook URL' do
      expect(webhook.url).to eq(webhook_url)
    end
  end

  describe '#actions' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'returns the webhook actions' do
      expect(webhook.actions).to eq(actions)
    end

    it 'returns empty array if no actions' do
      empty_response = api_response.dup
      empty_response[:data][:attributes].delete('actions')

      webhook = described_class.new(client: client, namespace_id: namespace_id, attributes: empty_response)

      expect(webhook.actions).to eq([])
    end
  end

  describe '#inspect' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'includes id, url (truncated), actions count, and changed status' do
      expect(webhook.inspect).to match(/Webhook/)
      expect(webhook.inspect).to include(webhook_id)
      expect(webhook.inspect).to include('https://my.endpoint')
      expect(webhook.inspect).to include('actions=2')
      expect(webhook.inspect).to include('changed=false')
    end

    it 'truncates long URLs' do
      long_url = 'https://' + 'a' * 100 + '.com/webhooks'
      webhook_with_long_url = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          data: {
            id: webhook_id,
            type: 'webhooks',
            attributes: { 'url' => long_url, 'actions' => actions }
          }
        }
      )

      inspect_output = webhook_with_long_url.inspect
      expect(inspect_output).to include('...')
      expect(inspect_output.scan(%r{https://a+}).first.length).to be <= 53 # 50 chars + '...'
    end
  end

  describe 'dirty tracking' do
    let(:webhook) do
      described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
    end

    it 'tracks changes to url' do
      expect(webhook.changed?).to be false

      webhook.url = 'https://new.endpoint.com/webhooks'

      expect(webhook.changed?).to be true
      expect(webhook.changes).not_to be_empty
    end

    it 'tracks changes to actions' do
      expect(webhook.changed?).to be false

      webhook.actions = ['video.ready', 'video.deleted']

      expect(webhook.changed?).to be true
      expect(webhook.changes).not_to be_empty
    end

    it 'tracks changes to metadata' do
      expect(webhook.changed?).to be false

      webhook.metadata[:labels][:status] = 'active'

      expect(webhook.changed?).to be true
      expect(webhook.changes).not_to be_empty
    end
  end
end
