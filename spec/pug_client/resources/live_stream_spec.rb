# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::LiveStream do
  let(:client) { PugClient::Client.new(namespace: 'test-namespace', client_id: 'test_id', client_secret: 'test_secret') }
  let(:namespace_id) { 'test-namespace' }
  let(:livestream_id) { 'livestream-uuid-123' }

  let(:api_response) do
    build_api_response(
      type: 'LiveStreams',
      id: livestream_id,
      attributes: {
        'streamStatus' => 'idle',
        'streamUrls' => { 'rtmp' => 'rtmp://example.com/live' },
        **build_metadata_timestamps
      }
    )
  end

  it_behaves_like 'a findable resource', 'livestreams', :livestream_id

  it_behaves_like 'a listable resource', 'livestreams'

  describe '.create' do
    it 'creates livestream with minimal attributes' do
      api_response = {
        data: {
          id: livestream_id,
          type: 'LiveStreams',
          attributes: {
            'streamStatus' => 'idle'
          }
        }
      }

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/livestreams",
        {
          data: {
            type: 'LiveStreams',
            attributes: {}
          }
        }
      ).and_return(api_response)

      livestream = described_class.create(client, namespace_id)

      expect(livestream).to be_a(described_class)
      expect(livestream.id).to eq(livestream_id)
      expect(livestream.namespace_id).to eq(namespace_id)
    end

    it 'creates livestream with all optional attributes' do
      started_at = Time.utc(2024, 1, 1, 12, 0, 0)
      location = { type: 'Point', coordinates: [-122.4194, 37.7749] }

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/livestreams",
        {
          data: {
            type: 'LiveStreams',
            attributes: {
              startedAt: '2024-01-01T12:00:00Z',
              metadata: {
                labels: { event: 'championship' },
                annotations: { gameId: '12345' }
              },
              location: location,
              simulcastTargets: %w[target-1 target-2]
            }
          }
        }
      ).and_return({
                     data: {
                       id: livestream_id,
                       type: 'LiveStreams',
                       attributes: { 'status' => 'idle' }
                     }
                   })

      livestream = described_class.create(
        client,
        namespace_id,
        started_at: started_at,
        metadata: {
          labels: { event: 'championship' },
          annotations: { game_id: '12345' }
        },
        location: location,
        simulcast_targets: %w[target-1 target-2]
      )

      expect(livestream).to be_a(described_class)
    end

    it 'converts Time objects to ISO8601' do
      started_at = Time.utc(2024, 1, 1, 12, 0, 0)

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/livestreams",
        hash_including(
          data: hash_including(
            attributes: hash_including(
              startedAt: '2024-01-01T12:00:00Z'
            )
          )
        )
      ).and_return({
                     data: {
                       id: livestream_id,
                       attributes: { 'status' => 'idle' }
                     }
                   })

      described_class.create(client, namespace_id, started_at: started_at)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:post)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        described_class.create(client, namespace_id)
      end.to raise_error(PugClient::NetworkError)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API response data' do
      api_data = {
        data: {
          id: livestream_id,
          type: 'LiveStreams',
          attributes: {
            'streamStatus' => 'active',
            'createdAt' => '2024-01-01T00:00:00Z'
          }
        }
      }

      livestream = described_class.from_api_data(
        client,
        api_data,
        _namespace_id: namespace_id
      )

      expect(livestream).to be_a(described_class)
      expect(livestream.id).to eq(livestream_id)
      expect(livestream.status).to eq('active')
      expect(livestream.namespace_id).to eq(namespace_id)
    end
  end

  # Shared resource instance for instance method tests
  let(:resource_instance) do
    described_class.new(
      client: client,
      namespace_id: namespace_id,
      attributes: {
        id: livestream_id,
        status: 'idle',
        metadata: { labels: { env: 'prod' } }
      }
    )
  end

  it_behaves_like 'a saveable resource', 'livestreams', :livestream_id do
    let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'streaming' } }
    let(:expected_patch) do
      [{ op: 'add', path: '/metadata/labels/status', value: 'streaming' }]
    end
  end

  describe '#save' do
    let(:livestream) { resource_instance }

    it 'handles multiple changes' do
      livestream.metadata[:labels][:version] = 'v2'
      livestream.metadata[:annotations] = { note: 'test' }

      expect(client).to receive(:patch).with(
        "namespaces/#{namespace_id}/livestreams/#{livestream_id}",
        hash_including(
          data: array_including(
            hash_including(op: 'add', path: '/metadata/labels/version'),
            hash_including(op: 'add', path: '/metadata/annotations')
          )
        )
      ).and_return({ data: { id: livestream_id, attributes: {} } })

      livestream.save
    end
  end

  it_behaves_like 'a reloadable resource', 'livestreams', :livestream_id do
    let(:updated_response) do
      api_response.dup.tap do |resp|
        resp[:data][:attributes]['streamStatus'] = 'active'
        resp[:data][:attributes]['metadata'] = { 'labels' => { 'env' => 'staging' } }
      end
    end
  end

  it_behaves_like 'a deletable resource', 'livestreams', :livestream_id

  describe '#publish' do
    let(:livestream) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: livestream_id, stream_status: 'idle' }
      )
    end

    it 'publishes livestream and reloads' do
      expect(client).to receive(:put)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}/publish", {})
        .and_return(true)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}")
        .and_return({
                      data: {
                        id: livestream_id,
                        attributes: { 'streamStatus' => 'active' }
                      }
                    })

      result = livestream.publish

      expect(result).to eq(livestream)
      expect(livestream.status).to eq('active')
    end

    it 'returns self for method chaining' do
      allow(client).to receive(:put).and_return(true)
      allow(client).to receive(:get).and_return({ data: { id: livestream_id, attributes: {} } })

      expect(livestream.publish).to eq(livestream)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:put)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        livestream.publish
      end.to raise_error(PugClient::NetworkError)
    end
  end

  describe '#unpublish' do
    let(:livestream) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: livestream_id, stream_status: 'active' }
      )
    end

    it 'unpublishes livestream and reloads' do
      expect(client).to receive(:put)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}/unpublish", {})
        .and_return(true)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}")
        .and_return({
                      data: {
                        id: livestream_id,
                        attributes: { 'streamStatus' => 'idle' }
                      }
                    })

      result = livestream.unpublish

      expect(result).to eq(livestream)
      expect(livestream.status).to eq('idle')
    end

    it 'returns self for method chaining' do
      allow(client).to receive(:put).and_return(true)
      allow(client).to receive(:get).and_return({ data: { id: livestream_id, attributes: {} } })

      expect(livestream.unpublish).to eq(livestream)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:put)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        livestream.unpublish
      end.to raise_error(PugClient::NetworkError)
    end
  end

  describe '#enable' do
    let(:livestream) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: livestream_id, stream_status: 'disabled' }
      )
    end

    it 'enables livestream and reloads' do
      expect(client).to receive(:put)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}/enable", {})
        .and_return(true)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}")
        .and_return({
                      data: {
                        id: livestream_id,
                        attributes: { 'streamStatus' => 'idle' }
                      }
                    })

      result = livestream.enable

      expect(result).to eq(livestream)
      expect(livestream.status).to eq('idle')
    end

    it 'returns self for method chaining' do
      allow(client).to receive(:put).and_return(true)
      allow(client).to receive(:get).and_return({ data: { id: livestream_id, attributes: {} } })

      expect(livestream.enable).to eq(livestream)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:put)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        livestream.enable
      end.to raise_error(PugClient::NetworkError)
    end
  end

  describe '#disable' do
    let(:livestream) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: livestream_id, stream_status: 'active' }
      )
    end

    it 'disables livestream and reloads' do
      expect(client).to receive(:put)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}/disable", {})
        .and_return(true)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/livestreams/#{livestream_id}")
        .and_return({
                      data: {
                        id: livestream_id,
                        attributes: { 'streamStatus' => 'disabled' }
                      }
                    })

      result = livestream.disable

      expect(result).to eq(livestream)
      expect(livestream.status).to eq('disabled')
    end

    it 'returns self for method chaining' do
      allow(client).to receive(:put).and_return(true)
      allow(client).to receive(:get).and_return({ data: { id: livestream_id, attributes: {} } })

      expect(livestream.disable).to eq(livestream)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:put)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        livestream.disable
      end.to raise_error(PugClient::NetworkError)
    end
  end

  it_behaves_like 'has namespace association'

  describe 'read-only attributes' do
    let(:livestream) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: livestream_id,
          stream_status: 'active',
          stream_urls: { rtmp: 'rtmp://ingest.example.com/live' },
          playback_urls: { hls: 'https://playback.example.com/stream.m3u8' },
          thumbnails: ['https://example.com/thumb1.jpg'],
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-02T00:00:00Z'
        }
      )
    end

    it 'prevents modification of id' do
      expect do
        livestream.id = 'new-id'
      end.to raise_error(PugClient::ValidationError, /read-only.*id/i)
    end

    it 'prevents modification of stream_status' do
      expect do
        livestream.stream_status = 'idle'
      end.to raise_error(PugClient::ValidationError, /read-only.*stream_status/i)
    end

    it 'prevents modification of stream_urls' do
      expect do
        livestream.stream_urls = { rtmp: 'rtmp://new.example.com' }
      end.to raise_error(PugClient::ValidationError, /read-only.*stream_urls/i)
    end

    it 'prevents modification of playback_urls' do
      expect do
        livestream.playback_urls = { hls: 'new-url' }
      end.to raise_error(PugClient::ValidationError, /read-only.*playback_urls/i)
    end

    it 'allows reading read-only attributes' do
      expect(livestream.id).to eq(livestream_id)
      expect(livestream.stream_status).to eq('active')
      expect(livestream.status).to eq('active')
      expect(livestream.stream_key).to eq(livestream_id)
      expect(livestream.rtmp_url).to eq('rtmp://ingest.example.com/live')
      expect(livestream.playback_urls).to eq({ hls: 'https://playback.example.com/stream.m3u8' })
    end

    it 'allows modification of other attributes' do
      expect { livestream.metadata = { labels: { test: 'value' } } }.not_to raise_error
      expect { livestream.location = { type: 'Point', coordinates: [-122.4194, 37.7749] } }.not_to raise_error
    end
  end

  it_behaves_like 'has dirty tracking' do
    let(:mutation) { -> { resource_instance.metadata[:labels][:viewers] = '1000' } }
  end

  describe 'dirty tracking integration' do
    let(:livestream) { resource_instance }

    it 'generates correct patch operations for multiple changes' do
      livestream.metadata[:labels][:version] = 'v2'
      livestream.metadata[:annotations] = { note: 'test livestream' }

      operations = livestream.generate_patch_operations

      expect(operations).to include(
        hash_including(op: 'add', path: '/metadata/labels/version', value: 'v2')
      )
      expect(operations).to include(
        hash_including(op: 'add', path: '/metadata/annotations')
      )
    end
  end

  describe '#inspect' do
    it 'provides human-readable representation' do
      livestream = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: livestream_id, stream_status: 'active' }
      )

      expect(livestream.inspect).to include('LiveStream')
      expect(livestream.inspect).to include(livestream_id)
      expect(livestream.inspect).to include('active')
    end

    it 'shows changed state' do
      livestream = resource_instance
      expect(livestream.inspect).to include('changed=false')

      livestream.metadata = { labels: { test: 'value' } }

      expect(livestream.inspect).to include('changed=true')
    end
  end
end
