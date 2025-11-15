# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'Videos Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }

  describe 'creating a video' do
    it 'creates a video with started_at timestamp' do
      started_at = '2025-01-15T10:00:00Z'
      video = client.create_video(started_at, metadata: { labels: { test: 'integration' } })

      expect(video).to be_a(PugClient::Resources::Video)
      expect(video.id).to be_a(String)
      expect(video.namespace_id).to eq(namespace_id)
      expect(video.started_at).to be_a(String)
      expect(video.metadata.dig(:labels, :test)).to eq('integration')

      # Clean up
      video.delete
    end

    it 'creates a video with custom metadata' do
      video = client.create_video(
        '2025-01-15T10:00:00Z',
        metadata: {
          labels: {
            environment: 'test',
            run_id: 'test-run-1'
          }
        }
      )

      expect(video.metadata[:labels]).to be_a(Hash)
      expect(video.metadata.dig(:labels, :environment)).to eq('test')

      # Clean up
      video.delete
    end
  end

  describe 'finding a video' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'retrieves video by ID' do
      found = client.video(video.id)

      expect(found).to be_a(PugClient::Resources::Video)
      expect(found.id).to eq(video.id)
      expect(found.namespace_id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound for non-existent video' do
      expect do
        client.video('non-existent-video-12345')
      end.to raise_error(PugClient::ResourceNotFound, /Video/)
    end
  end

  describe 'listing videos' do
    before do
      # Ensure at least one video exists
      @test_video = client.create_video('2025-01-15T10:00:00Z', metadata: { labels: { test: 'list' } })
    end

    after do
      @test_video.delete
    rescue StandardError
      nil
    end

    it 'lists videos with pagination' do
      videos = client.videos.first(5)

      expect(videos).to be_an(Array)
      expect(videos.length).to be <= 5
      videos.each do |video|
        expect(video).to be_a(PugClient::Resources::Video)
        expect(video.id).to be_a(String)
        expect(video.namespace_id).to eq(namespace_id)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.videos

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::Video)
    end

    it 'can iterate through all videos' do
      count = 0
      client.videos.first(3).each do |video|
        expect(video).to be_a(PugClient::Resources::Video)
        count += 1
      end
      expect(count).to be <= 3
    end
  end

  describe 'updating a video' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'updates video metadata via dirty tracking' do
      test_value = 'updated-status'
      video.metadata[:labels] ||= {}
      video.metadata[:labels][:status] = test_value

      expect(video.changed?).to be true
      expect(video.save).to be true
      expect(video.changed?).to be false

      # Verify the change persisted
      reloaded = client.video(video.id)
      expect(reloaded.metadata.dig(:labels, :status)).to eq(test_value)
    end

    it 'supports nested metadata updates' do
      # NOTE: Custom metadata must be in labels or annotations, not arbitrary nested structures
      video.metadata[:labels] ||= {}
      video.metadata[:labels][:custom_field] = 'value'

      expect(video.save).to be true

      reloaded = client.video(video.id)
      expect(reloaded.metadata.dig(:labels, :custom_field)).to eq('value')
    end

    it 'does not save when no changes made' do
      expect(video.changed?).to be false
      expect(video.save).to be true
    end
  end

  describe 'reloading a video' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'discards local changes and reloads from API' do
      video.metadata.dup

      # Make local change without saving
      video.metadata[:labels] ||= {}
      video.metadata[:labels][:temp] = 'should-be-discarded'
      expect(video.changed?).to be true

      # Reload discards the change
      video.reload
      expect(video.changed?).to be false
      expect(video.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'deleting a video' do
    it 'deletes a video' do
      video = client.create_video('2025-01-15T10:00:00Z')
      video_id = video.id

      expect(video.delete).to be true

      # Verify video is gone
      expect do
        client.video(video_id)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'freezes video object after deletion' do
      video = client.create_video('2025-01-15T10:00:00Z')
      video.delete

      expect(video.frozen?).to be true
      expect do
        video.metadata[:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe 'video upload URL' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'generates upload URL for video file' do
      result = video.upload_url('test-video.mp4')

      expect(result).to be_a(Hash)
      expect(result[:url]).to be_a(String)
      expect(result[:url]).to start_with('http')
    end
  end

  describe 'creating clips' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'creates a clip from video' do
      skip 'Clipping requires uploading a real MP4 file and waiting for background video processing to complete'

      clip = video.clip(start_time: 0, duration: 30_000)

      expect(clip).to be_a(PugClient::Resources::Video)
      expect(clip.id).to be_a(String)
      expect(clip.id).not_to eq(video.id)
      expect(clip.namespace_id).to eq(namespace_id)

      # Clean up clip
      clip.delete
    end

    it 'creates a clip with custom metadata' do
      skip 'Clipping requires uploading a real MP4 file and waiting for background video processing to complete'

      clip = video.clip(
        start_time: 10_000,
        duration: 15_000,
        metadata: { labels: { type: 'highlight' } }
      )

      expect(clip.metadata.dig(:labels, :type)).to eq('highlight')

      # Clean up
      clip.delete
    end
  end

  describe 'video relationships' do
    let(:video) { client.create_video('2025-01-15T10:00:00Z') }
    after do
      video.delete
    rescue StandardError
      nil
    end

    it 'accesses parent namespace' do
      namespace = video.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end
  end
end
