# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::Playlist do
  include_context 'resource spec client'

  let(:playlist_id) { 'playlist-123' }
  let(:video_ids) { %w[video-1 video-2 video-3] }

  let(:api_response) do
    build_api_response(
      type: 'playlists',
      id: playlist_id,
      attributes: {
        'videos' => video_ids,
        **build_metadata_timestamps,
        'metadata' => {
          'labels' => { 'type' => 'highlights' }
        }
      }
    )
  end

  it_behaves_like 'a findable resource', 'playlists', :playlist_id

  describe '.all' do
    it 'raises FeatureNotSupportedError' do
      expect do
        described_class.all(client, namespace_id)
      end.to raise_error(PugClient::FeatureNotSupportedError, /Playlist listing/)
    end
  end

  describe '.create' do
    it 'creates a new playlist with video IDs' do
      expected_body = {
        data: {
          type: 'playlists',
          attributes: {
            metadata: {},
            videos: video_ids
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/playlists", expected_body)
        .and_return(api_response)

      playlist = described_class.create(client, namespace_id, video_ids)

      expect(playlist).to be_a(described_class)
      expect(playlist.id).to eq(playlist_id)
      expect(playlist.namespace_id).to eq(namespace_id)
      expect(playlist.videos).to eq(video_ids)
    end

    it 'creates a playlist with metadata' do
      metadata = { labels: { type: 'highlights', event: 'championship' } }

      expected_body = {
        data: {
          type: 'playlists',
          attributes: {
            videos: video_ids,
            metadata: metadata
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/playlists", expected_body)
        .and_return(api_response)

      playlist = described_class.create(client, namespace_id, video_ids, metadata: metadata)

      expect(playlist).to be_a(described_class)
      expect(playlist.metadata).to eq(labels: { type: 'highlights' })
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/playlists", anything)
        .and_raise(StandardError.new('API error'))

      expect do
        described_class.create(client, namespace_id, video_ids)
      end.to raise_error(PugClient::NetworkError, /API error/)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API data with namespace_id' do
      playlist = described_class.from_api_data(client, api_response, _namespace_id: namespace_id)

      expect(playlist).to be_a(described_class)
      expect(playlist.id).to eq(playlist_id)
      expect(playlist.namespace_id).to eq(namespace_id)
    end
  end

  # Shared resource instance for instance method tests
  let(:resource_instance) do
    described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
  end

  describe '#save' do
    it 'raises NotImplementedError' do
      expect do
        resource_instance.save
      end.to raise_error(NotImplementedError, /Playlist updates are not supported/)
    end
  end

  it_behaves_like 'a reloadable resource', 'playlists', :playlist_id do
    let(:updated_response) do
      api_response.dup.tap { |resp| resp[:data][:attributes]['videos'] = %w[video-1 video-2] }
    end
  end

  describe '#delete' do
    it 'raises NotImplementedError' do
      expect do
        resource_instance.delete
      end.to raise_error(NotImplementedError, /Playlist deletion is not supported/)
    end
  end

  it_behaves_like 'has namespace association'

  describe '#videos' do
    it 'returns the videos array' do
      expect(resource_instance.videos).to eq(video_ids)
    end

    it 'returns empty array if no videos' do
      empty_response = api_response.dup
      empty_response[:data][:attributes].delete('videos')

      playlist = described_class.new(client: client, namespace_id: namespace_id, attributes: empty_response)

      expect(playlist.videos).to eq([])
    end
  end

  describe '#video_resources' do
    it 'fetches Video resources for each video ID' do
      video1 = instance_double(PugClient::Resources::Video, id: 'video-1')
      video2 = instance_double(PugClient::Resources::Video, id: 'video-2')
      video3 = instance_double(PugClient::Resources::Video, id: 'video-3')

      expect(PugClient::Resources::Video).to receive(:find)
        .with(client, namespace_id, 'video-1')
        .and_return(video1)
      expect(PugClient::Resources::Video).to receive(:find)
        .with(client, namespace_id, 'video-2')
        .and_return(video2)
      expect(PugClient::Resources::Video).to receive(:find)
        .with(client, namespace_id, 'video-3')
        .and_return(video3)

      resources = resource_instance.video_resources

      expect(resources).to eq([video1, video2, video3])
    end
  end

  describe '#inspect' do
    it 'includes id, video count, and changed status' do
      expect(resource_instance.inspect).to match(/Playlist/)
      expect(resource_instance.inspect).to include(playlist_id)
      expect(resource_instance.inspect).to include('videos=3')
      expect(resource_instance.inspect).to include('changed=false')
    end
  end

  it_behaves_like 'has dirty tracking' do
    let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'archived' } }
  end
end
