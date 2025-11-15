# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'LiveStreams Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }

  describe 'creating a live stream' do
    it 'creates a live stream with default options' do
      livestream = client.create_livestream

      expect(livestream).to be_a(PugClient::Resources::LiveStream)
      expect(livestream.id).to be_a(String)
      expect(livestream.namespace_id).to eq(namespace_id)
      expect(livestream.rtmp_url).to be_a(String)
      expect(livestream.stream_key).to be_a(String)

      # Clean up
      livestream.delete
    end

    it 'creates a live stream with custom metadata' do
      livestream = client.create_livestream(
        metadata: {
          labels: {
            event: 'integration-test',
            run_id: 'test-run-1'
          }
        }
      )

      expect(livestream.metadata[:labels]).to be_a(Hash)
      expect(livestream.metadata.dig(:labels, :event)).to eq('integration-test')

      # Clean up
      livestream.delete
    end
  end

  describe 'finding a live stream' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'retrieves live stream by ID' do
      found = client.livestream(livestream.id)

      expect(found).to be_a(PugClient::Resources::LiveStream)
      expect(found.id).to eq(livestream.id)
      expect(found.namespace_id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound for non-existent live stream' do
      expect do
        client.livestream('non-existent-livestream-12345')
      end.to raise_error(PugClient::ResourceNotFound, /LiveStream/)
    end
  end

  describe 'listing live streams' do
    before do
      # Ensure at least one live stream exists
      @test_livestream = client.create_livestream(
        metadata: { labels: { test: 'list' } }
      )
    end

    after do
      @test_livestream.delete
    rescue StandardError
      nil
    end

    it 'lists live streams with pagination' do
      livestreams = client.livestreams.first(5)

      expect(livestreams).to be_an(Array)
      expect(livestreams.length).to be <= 5
      livestreams.each do |stream|
        expect(stream).to be_a(PugClient::Resources::LiveStream)
        expect(stream.id).to be_a(String)
        expect(stream.namespace_id).to eq(namespace_id)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.livestreams

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::LiveStream)
    end
  end

  describe 'updating a live stream' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'updates live stream metadata via dirty tracking' do
      test_value = 'updated-status'
      livestream.metadata[:labels] ||= {}
      livestream.metadata[:labels][:status] = test_value

      expect(livestream.changed?).to be true
      expect(livestream.save).to be true
      expect(livestream.changed?).to be false

      # Verify the change persisted
      reloaded = client.livestream(livestream.id)
      expect(reloaded.metadata.dig(:labels, :status)).to eq(test_value)
    end

    it 'does not save when no changes made' do
      expect(livestream.changed?).to be false
      expect(livestream.save).to be true
    end
  end

  describe 'reloading a live stream' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'discards local changes and reloads from API' do
      # Make local change without saving
      livestream.metadata[:labels] ||= {}
      livestream.metadata[:labels][:temp] = 'should-be-discarded'
      expect(livestream.changed?).to be true

      # Reload discards the change
      livestream.reload
      expect(livestream.changed?).to be false
      expect(livestream.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'deleting a live stream' do
    it 'deletes a live stream' do
      livestream = client.create_livestream
      livestream_id = livestream.id

      expect(livestream.delete).to be true

      # Verify live stream is gone
      expect do
        client.livestream(livestream_id)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'freezes live stream object after deletion' do
      livestream = client.create_livestream
      livestream.delete

      expect(livestream.frozen?).to be true
      expect do
        livestream.metadata[:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe 'live stream status and configuration' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'provides RTMP URL for streaming' do
      expect(livestream.rtmp_url).to be_a(String)
      expect(livestream.rtmp_url).to start_with('rtmp')
    end

    it 'provides stream key for authentication' do
      expect(livestream.stream_key).to be_a(String)
      expect(livestream.stream_key.length).to be > 0
    end

    it 'reports live stream status' do
      expect(livestream.status).to be_a(String)
    end
  end

  describe 'publishing live streams' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'publishes a live stream' do
      result = livestream.publish

      expect(result).to be_truthy
      livestream.reload
      # Status may not immediately reflect published state
    end

    it 'unpublishes a live stream' do
      livestream.publish
      result = livestream.unpublish

      expect(result).to be_truthy
      livestream.reload
      # Status may not immediately reflect unpublished state
    end
  end

  describe 'enabling and disabling live streams' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'enables a live stream' do
      # Disable first to ensure we can enable (avoid 409 conflict)
      livestream.disable
      result = livestream.enable

      expect(result).to be_truthy
    end

    it 'disables a live stream' do
      result = livestream.disable

      expect(result).to be_truthy
    end
  end

  describe 'live stream relationships' do
    let(:livestream) { client.create_livestream }
    after do
      livestream.delete
    rescue StandardError
      nil
    end

    it 'accesses parent namespace' do
      namespace = livestream.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end
  end
end
