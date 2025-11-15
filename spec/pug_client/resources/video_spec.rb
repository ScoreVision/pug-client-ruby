# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::Video do
  include_context 'resource spec client'

  let(:video_id) { 'test-video' }

  describe '.find' do
    it 'fetches video by ID' do
      api_response = build_api_response(
        type: 'videos',
        id: video_id,
        attributes: {
          'startedAt' => '2025-01-01T00:00:00Z',
          'createdAt' => '2025-01-01T00:00:00Z',
          'metadata' => {
            'labels' => { 'game' => 'basketball' }
          }
        }
      )

      allow(client).to receive(:get)
        .with("namespaces/#{namespace_id}/videos/#{video_id}", {})
        .and_return(api_response)

      video = described_class.find(client, namespace_id, video_id)

      expect(video).to be_a(described_class)
      expect(video.id).to eq(video_id)
      expect(video.namespace_id).to eq(namespace_id)
      expect(video.started_at).to eq('2025-01-01T00:00:00Z')
      expect(video.metadata[:labels][:game]).to eq('basketball')
    end

    it 'raises ResourceNotFound when video does not exist' do
      stub_404_error(client, :get, "namespaces/#{namespace_id}/videos/#{video_id}")

      expect do
        described_class.find(client, namespace_id, video_id)
      end.to raise_error(PugClient::ResourceNotFound, /Video not found: test-video/)
    end

    it 'raises NetworkError for other API failures' do
      stub_network_error(client, :get, "namespaces/#{namespace_id}/videos/#{video_id}", message: 'Connection timeout')

      expect do
        described_class.find(client, namespace_id, video_id)
      end.to raise_error(PugClient::NetworkError, /Connection timeout/)
    end
  end

  describe '.all' do
    it 'returns ResourceEnumerator' do
      enumerator = described_class.all(client, namespace_id)

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.resource_class).to eq(described_class)
      expect(enumerator.base_url).to eq("namespaces/#{namespace_id}/videos")
    end

    it 'passes namespace_id in options' do
      enumerator = described_class.all(client, namespace_id)

      expect(enumerator.options[:_namespace_id]).to eq(namespace_id)
    end
  end

  describe '.create' do
    it 'creates video with started_at' do
      started_at = '2025-01-01T00:00:00Z'

      api_response = build_api_response(
        type: 'videos',
        id: video_id,
        attributes: { 'startedAt' => started_at }
      )

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/videos", {
                data: {
                  type: 'videos',
                  attributes: {
                    startedAt: started_at
                  }
                }
              })
        .and_return(api_response)

      video = described_class.create(client, namespace_id, started_at)

      expect(video).to be_a(described_class)
      expect(video.id).to eq(video_id)
      expect(video.namespace_id).to eq(namespace_id)
    end

    it 'converts Time to ISO8601' do
      started_at = Time.utc(2025, 1, 1, 0, 0, 0)

      api_response = build_api_response(
        type: 'videos',
        id: video_id,
        attributes: { 'startedAt' => '2025-01-01T00:00:00Z' }
      )

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/videos", hash_including(
                                                     data: hash_including(
                                                       attributes: hash_including(startedAt: '2025-01-01T00:00:00Z')
                                                     )
                                                   ))
        .and_return(api_response)

      video = described_class.create(client, namespace_id, started_at)
      expect(video.started_at).to eq('2025-01-01T00:00:00Z')
    end

    it 'creates video with metadata' do
      started_at = '2025-01-01T00:00:00Z'
      options = {
        metadata: {
          labels: { game: 'basketball', highlight: true }
        }
      }

      api_response = build_api_response(
        type: 'videos',
        id: video_id,
        attributes: {
          'startedAt' => started_at,
          'metadata' => {
            'labels' => { 'game' => 'basketball', 'highlight' => true }
          }
        }
      )

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/videos", {
                data: {
                  type: 'videos',
                  attributes: {
                    startedAt: started_at,
                    metadata: {
                      labels: { game: 'basketball', highlight: true }
                    }
                  }
                }
              })
        .and_return(api_response)

      video = described_class.create(client, namespace_id, started_at, options)
      expect(video.metadata[:labels][:game]).to eq('basketball')
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :post, "namespaces/#{namespace_id}/videos", message: 'API Error')

      expect do
        described_class.create(client, namespace_id, '2025-01-01T00:00:00Z')
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API response data' do
      data = {
        id: video_id,
        type: 'videos',
        attributes: {
          'startedAt' => '2025-01-01T00:00:00Z'
        }
      }

      video = described_class.from_api_data(client, data, _namespace_id: namespace_id)

      expect(video).to be_a(described_class)
      expect(video.id).to eq(video_id)
      expect(video.namespace_id).to eq(namespace_id)
    end
  end

  describe '#save' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: video_id,
          started_at: '2025-01-01T00:00:00Z',
          metadata: { labels: { game: 'basketball' } }
        }
      )
    end

    it 'returns true when no changes' do
      expect(video.save).to be true
    end

    it 'sends JSON Patch when changes exist' do
      video.metadata[:labels][:status] = 'processed'

      expect(client).to receive(:patch)
        .with("namespaces/#{namespace_id}/videos/#{video_id}", {
                data: [
                  {
                    op: 'add',
                    path: '/metadata/labels/status',
                    value: 'processed'
                  }
                ]
              })
        .and_return({
                      data: {
                        id: video_id,
                        attributes: {
                          'metadata' => { 'labels' => { 'game' => 'basketball', 'status' => 'processed' } }
                        }
                      }
                    })

      result = video.save

      expect(result).to be true
      expect(video.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      video.metadata[:labels][:status] = 'processed'

      stub_network_error(client, :patch, "namespaces/#{namespace_id}/videos/#{video_id}", message: 'API Error')

      expect do
        video.save
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#reload' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: video_id,
          metadata: { labels: { game: 'basketball' } }
        }
      )
    end

    it 'fetches latest data from API' do
      video.metadata[:labels][:status] = 'processed' # Local change

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/videos/#{video_id}")
        .and_return({
                      data: {
                        id: video_id,
                        attributes: {
                          'metadata' => { 'labels' => { 'game' => 'basketball', 'new' => 'value' } }
                        }
                      }
                    })

      result = video.reload

      expect(result).to eq(video)
      expect(video.metadata[:labels][:new]).to eq('value')
      expect(video.metadata[:labels][:status]).to be_nil
      expect(video.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :get, message: 'API Error')

      expect do
        video.reload
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#delete' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: video_id,
          metadata: { labels: {} }
        }
      )
    end

    it 'deletes video from API' do
      expect(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/videos/#{video_id}")
        .and_return(true)

      result = video.delete

      expect(result).to be true
      expect(video).to be_frozen
    end

    it 'prevents modifications after deletion' do
      allow(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/videos/#{video_id}")
        .and_return(true)

      video.delete

      expect do
        video.metadata[:labels][:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :delete, message: 'API Error')

      expect do
        video.delete
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#clip' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: video_id }
      )
    end

    it 'creates clip video' do
      clip_response = build_api_response(
        type: 'videos',
        id: 'clip-123',
        attributes: {
          'startedAt' => '2025-01-01T00:00:05Z',
          'duration' => 30_000
        }
      )

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/videos/#{video_id}/commands", {
                data: {
                  attributes: {
                    command: 'clip',
                    startTime: 5000,
                    duration: 30_000
                  }
                }
              })
        .and_return(clip_response)

      clip = video.clip(start_time: 5000, duration: 30_000)

      expect(clip).to be_a(described_class)
      expect(clip.id).to eq('clip-123')
      expect(clip.namespace_id).to eq(namespace_id)
    end

    it 'creates clip with metadata' do
      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/videos/#{video_id}/commands", {
                data: {
                  attributes: {
                    command: 'clip',
                    startTime: 5000,
                    duration: 30_000,
                    metadata: {
                      labels: { type: 'highlight' }
                    }
                  }
                }
              })
        .and_return({
                      data: {
                        id: 'clip-123',
                        attributes: {}
                      }
                    })

      video.clip(start_time: 5000, duration: 30_000, metadata: { labels: { type: 'highlight' } })
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :post, "namespaces/#{namespace_id}/videos/#{video_id}/commands", message: 'API Error')

      expect do
        video.clip(start_time: 5000, duration: 30_000)
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#upload_url' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: video_id }
      )
    end

    it 'gets signed upload URL' do
      upload_response = {
        data: {
          attributes: {
            'url' => 'https://storage.example.com/upload',
            'expiration' => '2025-01-01T01:00:00Z'
          }
        }
      }

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/videos/#{video_id}/upload-urls/video.mp4", {})
        .and_return(upload_response)

      upload_info = video.upload_url('video.mp4')

      expect(upload_info[:url]).to eq('https://storage.example.com/upload')
      expect(upload_info[:expiration]).to eq('2025-01-01T01:00:00Z')
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :get, "namespaces/#{namespace_id}/videos/#{video_id}/upload-urls/video.mp4",
                         message: 'API Error')

      expect do
        video.upload_url('video.mp4')
      end.to raise_error(PugClient::NetworkError, /API Error/)
    end
  end

  describe '#upload' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: video_id }
      )
    end

    let(:file_io) { StringIO.new('video data') }

    it 'validates content type' do
      expect do
        video.upload(file_io, filename: 'video.avi', content_type: 'video/avi')
      end.to raise_error(PugClient::ValidationError, %r{Unsupported content type: video/avi})
    end

    it 'uploads file with valid content type' do
      upload_info = {
        url: 'https://storage.example.com/upload',
        headers: { 'X-Custom-Header' => 'value' }
      }

      allow(video).to receive(:upload_url).with('video.mp4').and_return(upload_info)

      conn = double('Faraday Connection')
      response = double('Response', success?: true)

      allow(Faraday).to receive(:new).and_yield(double.as_null_object).and_return(conn)

      expect(conn).to receive(:put).with('https://storage.example.com/upload').and_yield(
        double('Request').tap do |req|
          allow(req).to receive(:headers).and_return({})
          allow(req).to receive(:body=)
        end
      ).and_return(response)

      result = video.upload(file_io, filename: 'video.mp4')
      expect(result).to be true
    end

    it 'raises NetworkError on upload failure' do
      upload_info = { url: 'https://storage.example.com/upload' }
      allow(video).to receive(:upload_url).and_return(upload_info)

      conn = double('Faraday Connection')
      response = double('Response', success?: false, status: 500)

      allow(Faraday).to receive(:new).and_yield(double.as_null_object).and_return(conn)
      allow(conn).to receive(:put).and_return(response)

      expect do
        video.upload(file_io, filename: 'video.mp4')
      end.to raise_error(PugClient::NetworkError, /Upload failed: 500/)
    end
  end

  describe '#wait_until_ready' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: video_id,
          renditions: nil
        }
      )
    end

    it 'returns true when renditions available' do
      allow(video).to receive(:reload) do
        video.instance_variable_get(:@current_attributes)[:renditions] = [{ format: 'hls' }]
      end

      result = video.wait_until_ready(timeout: 1, interval: 0.1)
      expect(result).to be true
    end

    it 'raises TimeoutError when timeout exceeded' do
      allow(video).to receive(:reload) # Returns nil renditions

      expect do
        video.wait_until_ready(timeout: 0.5, interval: 0.1)
      end.to raise_error(PugClient::TimeoutError, /Video not ready after 0.5s/)
    end
  end

  describe '#namespace' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: video_id }
      )
    end

    it 'fetches and caches namespace' do
      namespace = double('Namespace')

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .once
        .and_return(namespace)

      # Call twice to test caching
      result1 = video.namespace
      result2 = video.namespace

      expect(result1).to eq(namespace)
      expect(result2).to eq(namespace)
    end
  end

  describe 'read-only attributes' do
    let(:video) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: video_id,
          created_at: '2025-01-01T00:00:00Z',
          updated_at: '2025-01-01T00:00:00Z',
          duration: 120_000,
          renditions: [{ format: 'hls' }],
          playback_urls: { hls: 'https://example.com/video.m3u8' },
          thumbnail_url: 'https://example.com/thumb.jpg'
        }
      )
    end

    it 'prevents modification of id' do
      expect do
        video.id = 'new-id'
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: id/)
    end

    it 'prevents modification of duration' do
      expect do
        video.duration = 90_000
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: duration/)
    end

    it 'prevents modification of renditions' do
      expect do
        video.renditions = []
      end.to raise_error(PugClient::ValidationError, /Cannot modify read-only attribute: renditions/)
    end

    it 'allows reading read-only attributes' do
      expect(video.id).to eq(video_id)
      expect(video.duration).to eq(120_000)
      expect(video.renditions).to be_an(Array)
    end
  end

  describe 'SUPPORTED_CONTENT_TYPES' do
    it 'includes video/mp4' do
      expect(described_class::SUPPORTED_CONTENT_TYPES).to include('video/mp4')
    end
  end
end
