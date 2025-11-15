# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'Playlists Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }

  # Helper to create test videos for playlists
  let(:test_video1) { client.create_video(Time.now.utc.iso8601, metadata: { labels: { test: 'playlist1' } }) }
  let(:test_video2) { client.create_video(Time.now.utc.iso8601, metadata: { labels: { test: 'playlist2' } }) }

  after do
    begin
      test_video1.delete
    rescue StandardError
      nil
    end
    begin
      test_video2.delete
    rescue StandardError
      nil
    end
  end

  describe 'creating a playlist' do
    it 'creates a playlist with video IDs' do
      video_ids = [test_video1.id, test_video2.id]
      playlist = client.create_playlist(video_ids)

      expect(playlist).to be_a(PugClient::Resources::Playlist)
      expect(playlist.id).to be_a(String)
      expect(playlist.namespace_id).to eq(namespace_id)
      expect(playlist.videos).to be_an(Array)
      expect(playlist.videos).to include(test_video1.id, test_video2.id)
    end

    it 'creates a playlist with metadata' do
      video_ids = [test_video1.id]
      playlist = client.create_playlist(
        video_ids,
        metadata: {
          labels: {
            type: 'highlights',
            season: '2025'
          }
        }
      )

      expect(playlist.metadata[:labels]).to be_a(Hash)
      expect(playlist.metadata.dig(:labels, :type)).to eq('highlights')
    end
  end

  describe 'finding a playlist' do
    let(:playlist) { client.create_playlist([test_video1.id]) }

    it 'retrieves playlist by ID' do
      found = client.playlist(playlist.id)

      expect(found).to be_a(PugClient::Resources::Playlist)
      expect(found.id).to eq(playlist.id)
      expect(found.namespace_id).to eq(namespace_id)
      expect(found.videos).to be_an(Array)
    end

    it 'raises ResourceNotFound for non-existent playlist' do
      expect do
        client.playlist('non-existent-playlist-12345')
      end.to raise_error(PugClient::ResourceNotFound, /Playlist/)
    end
  end

  describe 'listing playlists' do
    it 'raises FeatureNotSupportedError' do
      expect do
        client.playlists
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /Playlist listing is not supported/
      )
    end

    it 'provides helpful error message' do
      expect do
        client.playlists
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /does not provide an endpoint for listing playlists/
      )
    end
  end

  describe 'reloading a playlist' do
    let(:playlist) { client.create_playlist([test_video1.id]) }

    it 'discards local changes and reloads from API' do
      # Make local change without saving
      playlist.metadata[:labels] ||= {}
      playlist.metadata[:labels][:temp] = 'should-be-discarded'
      expect(playlist.changed?).to be true

      # Reload discards the change
      playlist.reload
      expect(playlist.changed?).to be false
      expect(playlist.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'playlist relationships' do
    let(:playlist) { client.create_playlist([test_video1.id, test_video2.id]) }

    it 'accesses parent namespace' do
      namespace = playlist.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'provides video IDs' do
      expect(playlist.videos).to be_an(Array)
      expect(playlist.videos).to include(test_video1.id, test_video2.id)
    end
  end
end
