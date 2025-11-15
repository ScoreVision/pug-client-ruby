# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Client namespace integration' do
  let(:client) do
    PugClient::Client.new(
      environment: :staging,
      namespace: 'test-namespace',
      client_id: 'test',
      client_secret: 'test'
    )
  end

  describe '#namespace' do
    it 'returns Namespace resource' do
      api_response = {
        data: {
          id: 'test-namespace',
          type: 'namespaces',
          attributes: {
            'createdAt' => '2025-01-01T00:00:00Z',
            'metadata' => { 'labels' => { 'env' => 'prod' } }
          }
        }
      }

      # Mock the connection module's get method
      allow(client).to receive(:get)
        .with('namespaces/test-namespace', {})
        .and_return(api_response)

      namespace = client.namespace('test-namespace')

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq('test-namespace')
      expect(namespace.metadata[:labels][:env]).to eq('prod')
    end
  end

  describe '#create_namespace' do
    it 'creates and returns Namespace resource' do
      options = {
        metadata: {
          labels: { env: 'staging' }
        }
      }

      api_response = {
        data: {
          id: 'new-namespace',
          type: 'namespaces',
          attributes: {
            'metadata' => { 'labels' => { 'env' => 'staging' } }
          }
        }
      }

      expect(client).to receive(:post)
        .with('namespaces', hash_including(
                              data: hash_including(
                                type: 'namespaces',
                                id: 'new-namespace'
                              )
                            ))
        .and_return(api_response)

      namespace = client.create_namespace('new-namespace', options)

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq('new-namespace')
      expect(namespace.metadata[:labels][:env]).to eq('staging')
    end
  end

  describe '#namespaces' do
    it 'returns ResourceEnumerator' do
      enumerator = client.namespaces

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.resource_class).to eq(PugClient::Resources::Namespace)
      expect(enumerator.base_url).to eq('namespaces')
    end

    it 'enumerator yields Namespace resources' do
      api_response = [
        {
          id: 'namespace-1',
          type: 'namespaces',
          attributes: { 'metadata' => {} }
        },
        {
          id: 'namespace-2',
          type: 'namespaces',
          attributes: { 'metadata' => {} }
        }
      ]

      allow(client).to receive(:get)
        .and_return(api_response)

      namespaces = client.namespaces.first(2)

      expect(namespaces).to all(be_a(PugClient::Resources::Namespace))
      expect(namespaces.map(&:id)).to eq(%w[namespace-1 namespace-2])
    end
  end

  describe '#user_namespaces' do
    it 'returns ResourceEnumerator with user endpoint' do
      enumerator = client.user_namespaces

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.resource_class).to eq(PugClient::Resources::Namespace)
      expect(enumerator.base_url).to eq('user/namespaces')
    end

    it 'enumerator yields Namespace resources' do
      api_response = [
        {
          id: 'user-namespace',
          type: 'namespaces',
          attributes: { 'metadata' => {} }
        }
      ]

      allow(client).to receive(:get)
        .and_return(api_response)

      namespaces = client.user_namespaces.to_a

      expect(namespaces).to all(be_a(PugClient::Resources::Namespace))
      expect(namespaces.first.id).to eq('user-namespace')
    end
  end

  describe 'namespace resource operations' do
    it 'allows chaining operations' do
      # Create namespace
      create_response = {
        data: {
          id: 'test-namespace',
          type: 'namespaces',
          attributes: {
            'metadata' => { 'labels' => { 'env' => 'staging' } }
          }
        }
      }

      expect(client).to receive(:post)
        .and_return(create_response)

      namespace = client.create_namespace('test-namespace',
                                          metadata: { labels: { env: 'staging' } })

      # Update namespace
      namespace.metadata[:labels][:status] = 'active'

      patch_response = {
        data: {
          id: 'test-namespace',
          attributes: {
            'metadata' => { 'labels' => { 'env' => 'staging', 'status' => 'active' } }
          }
        }
      }

      expect(client).to receive(:patch)
        .with('namespaces/test-namespace', hash_including(
                                             data: array_including(
                                               hash_including(op: 'add', path: '/metadata/labels/status')
                                             )
                                           ))
        .and_return(patch_response)

      expect(namespace.save).to be true
      expect(namespace.metadata[:labels][:status]).to eq('active')
    end
  end
end
