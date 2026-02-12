# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::Namespace do
  include_context 'resource spec client'

  let(:api_response) do
    build_api_response(
      type: 'namespaces',
      id: namespace_id,
      attributes: {
        **build_metadata_timestamps,
        'metadata' => {
          'labels' => { 'env' => 'prod' }
        }
      }
    )
  end

  describe '.find' do
    it 'fetches namespace by ID' do
      allow(client).to receive(:get)
        .with("namespaces/#{namespace_id}", {})
        .and_return(api_response)

      namespace = described_class.find(client, namespace_id)

      expect(namespace).to be_a(described_class)
      expect(namespace.id).to eq(namespace_id)
      expect(namespace.created_at).to eq('2024-01-01T00:00:00Z')
      expect(namespace.metadata[:labels][:env]).to eq('prod')
    end

    it 'raises ResourceNotFound when namespace does not exist' do
      stub_404_error(client, :get, "namespaces/#{namespace_id}")

      expect do
        described_class.find(client, namespace_id)
      end.to raise_error(PugClient::ResourceNotFound, /Namespace not found: test-namespace/)
    end

    it 'raises NetworkError for other API failures' do
      stub_network_error(client, :get, "namespaces/#{namespace_id}", message: 'Connection timeout')

      expect do
        described_class.find(client, namespace_id)
      end.to raise_error(PugClient::NetworkError, /Connection timeout/)
    end
  end

  describe '.create' do
    it 'creates namespace with ID only' do
      api_response = {
        data: {
          id: namespace_id,
          type: 'namespaces',
          attributes: {}
        }
      }

      expect(client).to receive(:post)
        .with('namespaces', {
                data: {
                  type: 'namespaces',
                  id: namespace_id,
                  attributes: {}
                }
              })
        .and_return(api_response)

      namespace = described_class.create(client, namespace_id)

      expect(namespace).to be_a(described_class)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'creates namespace with metadata' do
      options = {
        metadata: {
          labels: { env: 'staging', team: 'video' },
          annotations: { project: 'test' }
        }
      }

      api_response = {
        data: {
          id: namespace_id,
          type: 'namespaces',
          attributes: {
            'metadata' => {
              'labels' => { 'env' => 'staging', 'team' => 'video' },
              'annotations' => { 'project' => 'test' }
            }
          }
        }
      }

      expect(client).to receive(:post)
        .with('namespaces', {
                data: {
                  type: 'namespaces',
                  id: namespace_id,
                  attributes: {
                    metadata: {
                      labels: { env: 'staging', team: 'video' },
                      annotations: { project: 'test' }
                    }
                  }
                }
              })
        .and_return(api_response)

      namespace = described_class.create(client, namespace_id, options)

      expect(namespace.metadata[:labels][:env]).to eq('staging')
      expect(namespace.metadata[:annotations][:project]).to eq('test')
    end

    it 'raises NetworkError on API failure' do
      allow(client).to receive(:post)
        .and_raise(StandardError.new('API Error'))

      expect do
        described_class.create(client, namespace_id)
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '.all' do
    it 'returns ResourceEnumerator' do
      enumerator = described_class.all(client)

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.resource_class).to eq(described_class)
      expect(enumerator.base_url).to eq('namespaces')
    end

    it 'passes options to enumerator' do
      options = { query: { filter: { label: 'test' } } }
      enumerator = described_class.all(client, options)

      expect(enumerator.options).to eq(options)
    end
  end

  describe '.for_user' do
    it 'returns ResourceEnumerator with user endpoint' do
      enumerator = described_class.for_user(client)

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.resource_class).to eq(described_class)
      expect(enumerator.base_url).to eq('user/namespaces')
    end

    it 'passes options to enumerator' do
      options = { query: { page: { size: 25 } } }
      enumerator = described_class.for_user(client, options)

      expect(enumerator.options).to eq(options)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API response data' do
      data = {
        id: namespace_id,
        type: 'namespaces',
        attributes: {
          'metadata' => { 'labels' => { 'env' => 'prod' } }
        }
      }

      namespace = described_class.from_api_data(client, data)

      expect(namespace).to be_a(described_class)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'accepts options parameter' do
      data = { id: namespace_id }

      # Should not raise error
      namespace = described_class.from_api_data(client, data, {})
      expect(namespace).to be_a(described_class)
    end
  end

  # Shared resource instance for instance method tests
  let(:resource_instance) do
    described_class.new(
      client: client,
      attributes: {
        id: namespace_id,
        created_at: '2025-01-01T00:00:00Z',
        updated_at: '2025-01-01T00:00:00Z',
        metadata: { labels: { env: 'prod' } }
      }
    )
  end

  describe '#save' do
    let(:namespace) { resource_instance }

    it 'returns true when no changes' do
      expect(namespace.save).to be true
    end

    it 'sends JSON Patch when changes exist' do
      namespace.metadata[:labels][:env] = 'staging'

      expect(client).to receive(:patch)
        .with("namespaces/#{namespace_id}", {
                data: [
                  {
                    op: 'replace',
                    path: '/metadata/labels/env',
                    value: 'staging'
                  }
                ]
              })
        .and_return({
                      data: {
                        id: namespace_id,
                        attributes: {
                          'metadata' => { 'labels' => { 'env' => 'staging' } }
                        }
                      }
                    })

      result = namespace.save

      expect(result).to be true
      expect(namespace.changed?).to be false
      expect(namespace.metadata[:labels][:env]).to eq('staging')
    end

    it 'handles multiple changes' do
      namespace.metadata[:labels][:env] = 'staging'
      namespace.metadata[:labels][:new_key] = 'value'

      expect(client).to receive(:patch)
        .with("namespaces/#{namespace_id}", hash_including(
                                              data: array_including(
                                                hash_including(op: 'replace', path: '/metadata/labels/env'),
                                                hash_including(op: 'add', path: '/metadata/labels/new_key')
                                              )
                                            ))
        .and_return({
                      data: {
                        id: namespace_id,
                        attributes: {
                          'metadata' => {
                            'labels' => { 'env' => 'staging', 'newKey' => 'value' }
                          }
                        }
                      }
                    })

      namespace.save
    end

    it 'raises NetworkError on API failure' do
      namespace.metadata[:labels][:env] = 'staging'

      allow(client).to receive(:patch)
        .and_raise(StandardError.new('API Error'))

      expect do
        namespace.save
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#reload' do
    let(:namespace) { resource_instance }

    it 'fetches latest data from API' do
      namespace.metadata[:labels][:env] = 'staging' # Make local change

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}")
        .and_return({
                      data: {
                        id: namespace_id,
                        attributes: {
                          'metadata' => { 'labels' => { 'env' => 'prod', 'new' => 'value' } }
                        }
                      }
                    })

      result = namespace.reload

      expect(result).to eq(namespace)
      expect(namespace.metadata[:labels][:env]).to eq('prod')
      expect(namespace.metadata[:labels][:new]).to eq('value')
      expect(namespace.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      allow(client).to receive(:get)
        .and_raise(StandardError.new('API Error'))

      expect do
        namespace.reload
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#delete' do
    let(:namespace) { resource_instance }

    it 'deletes namespace from API' do
      expect(client).to receive(:delete)
        .with("namespaces/#{namespace_id}")
        .and_return(true)

      result = namespace.delete

      expect(result).to be true
      expect(namespace).to be_frozen
    end

    it 'prevents modifications after deletion' do
      allow(client).to receive(:delete)
        .with("namespaces/#{namespace_id}")
        .and_return(true)

      namespace.delete

      expect do
        namespace.metadata[:labels][:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end

    it 'raises NetworkError on API failure' do
      allow(client).to receive(:delete)
        .and_raise(StandardError.new('API Error'))

      expect do
        namespace.delete
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe 'read-only attributes' do
    let(:namespace) { resource_instance }

    it 'prevents modification of id' do
      expect do
        namespace.id = 'new-id'
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: id/)
    end

    it 'prevents modification of created_at' do
      expect do
        namespace.created_at = '2025-01-02T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: created_at/)
    end

    it 'prevents modification of updated_at' do
      expect do
        namespace.updated_at = '2025-01-02T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: updated_at/)
    end

    it 'allows reading read-only attributes' do
      expect(namespace.id).to eq(namespace_id)
      expect(namespace.created_at).to eq('2025-01-01T00:00:00Z')
      expect(namespace.updated_at).to eq('2025-01-01T00:00:00Z')
    end
  end

  describe 'collection methods' do
    let(:namespace) do
      described_class.new(
        client: client,
        attributes: { id: namespace_id }
      )
    end

    describe '#videos' do
      it 'returns ResourceEnumerator for videos' do
        enumerator = namespace.videos

        expect(enumerator).to be_a(PugClient::ResourceEnumerator)
        expect(enumerator.resource_class).to eq(PugClient::Resources::Video)
        expect(enumerator.base_url).to eq("namespaces/#{namespace_id}/videos")
      end

      it 'passes options to enumerator' do
        options = { query: { filter: { status: 'ready' } } }
        enumerator = namespace.videos(options)

        expect(enumerator.options).to include(options)
      end
    end

    describe '#create_video' do
      it 'creates video in namespace' do
        started_at = '2025-01-01T00:00:00Z'

        expect(PugClient::Resources::Video).to receive(:create)
          .with(client, namespace_id, started_at, {})
          .and_return(double('Video', id: 'video-123'))

        video = namespace.create_video(started_at)
        expect(video.id).to eq('video-123')
      end

      it 'passes options to Video.create' do
        started_at = '2025-01-01T00:00:00Z'
        options = { metadata: { labels: { game: 'basketball' } } }

        expect(PugClient::Resources::Video).to receive(:create)
          .with(client, namespace_id, started_at, options)

        namespace.create_video(started_at, options)
      end
    end

    describe '#livestreams' do
      it 'returns ResourceEnumerator for livestreams' do
        enumerator = namespace.livestreams

        expect(enumerator).to be_a(PugClient::ResourceEnumerator)
        expect(enumerator.resource_class).to eq(PugClient::Resources::LiveStream)
      end

      it 'passes options to enumerator' do
        enumerator = namespace.livestreams(page: { size: 20 })

        expect(enumerator.options).to include(page: { size: 20 })
      end
    end

    describe '#create_livestream' do
      it 'creates livestream in namespace' do
        options = { metadata: { labels: { event: 'championship' } } }

        expect(PugClient::Resources::LiveStream).to receive(:create)
          .with(client, namespace_id, options)

        namespace.create_livestream(options)
      end

      it 'passes options to LiveStream.create' do
        started_at = Time.utc(2024, 1, 1)
        options = { started_at: started_at, metadata: { labels: { event: 'game' } } }

        expect(PugClient::Resources::LiveStream).to receive(:create)
          .with(client, namespace_id, options)

        namespace.create_livestream(options)
      end
    end

    describe '#campaigns' do
      it 'returns ResourceEnumerator for campaigns' do
        enumerator = namespace.campaigns

        expect(enumerator).to be_a(PugClient::ResourceEnumerator)
        expect(enumerator.resource_class).to eq(PugClient::Resources::Campaign)
      end

      it 'passes options to enumerator' do
        enumerator = namespace.campaigns(page: { size: 20 })

        expect(enumerator.options).to include(page: { size: 20 })
      end
    end

    describe '#create_campaign' do
      it 'creates campaign in namespace' do
        name = 'Summer 2024 Campaign'
        slug = 'summer-2024'
        options = { metadata: { labels: { season: 'summer' } } }

        expect(PugClient::Resources::Campaign).to receive(:create)
          .with(client, namespace_id, name, slug, options)

        namespace.create_campaign(name, slug, options)
      end

      it 'passes options to Campaign.create' do
        name = 'Winter 2024 Campaign'
        slug = 'winter-2024'
        start_time = Time.utc(2024, 12, 1)
        options = { start_time: start_time, metadata: { labels: { season: 'winter' } } }

        expect(PugClient::Resources::Campaign).to receive(:create)
          .with(client, namespace_id, name, slug, options)

        namespace.create_campaign(name, slug, options)
      end
    end

    describe '#clients' do
      it 'raises NotImplementedError with helpful message' do
        expect do
          namespace.clients
        end.to raise_error(NotImplementedError, /does not support listing namespace clients/)
      end
    end

    describe '#create_client' do
      it 'creates namespace client' do
        options = { metadata: { labels: { env: 'production' } } }

        expect(PugClient::Resources::NamespaceClient).to receive(:create)
          .with(client, namespace_id, options)

        namespace.create_client(options)
      end

      it 'passes options to NamespaceClient.create' do
        options = { metadata: { labels: { purpose: 'testing' } } }

        expect(PugClient::Resources::NamespaceClient).to receive(:create)
          .with(client, namespace_id, options)

        namespace.create_client(options)
      end
    end
  end

  it_behaves_like 'has dirty tracking' do
    let(:mutation) { -> { resource_instance.metadata[:labels][:env] = 'staging' } }
  end

  describe 'dirty tracking integration' do
    let(:namespace) { resource_instance }

    it 'generates correct patch operations' do
      namespace.metadata[:labels][:env] = 'staging'

      patches = namespace.generate_patch_operations
      expect(patches.size).to eq(1)
      expect(patches.first).to include(
        op: 'replace',
        path: '/metadata/labels/env',
        value: 'staging'
      )
    end
  end

  describe '#inspect' do
    it 'provides human-readable representation' do
      namespace = described_class.new(
        client: client,
        attributes: { id: namespace_id }
      )
      inspect_str = namespace.inspect
      expect(inspect_str).to include('PugClient::Resources::Namespace')
      expect(inspect_str).to include('id="test-namespace"')
      expect(inspect_str).to include('changed=false')
    end

    it 'shows changed state' do
      namespace = resource_instance
      namespace.mark_dirty!
      inspect_str = namespace.inspect
      expect(inspect_str).to include('changed=true')
    end
  end
end
