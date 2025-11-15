# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'SimulcastTargets Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }
  let(:test_rtmp_url) { 'rtmp://test.example.com/live/test-stream' }

  describe 'creating a simulcast target' do
    it 'creates a simulcast target with URL' do
      target = client.create_simulcast_target(test_rtmp_url)

      expect(target).to be_a(PugClient::Resources::SimulcastTarget)
      expect(target.id).to be_a(String)
      expect(target.namespace_id).to eq(namespace_id)
      expect(target.url).to eq(test_rtmp_url)

      # Clean up
      target.delete
    end

    it 'creates a simulcast target with metadata' do
      target = client.create_simulcast_target(
        test_rtmp_url,
        metadata: {
          labels: {
            platform: 'youtube',
            event: 'test-stream'
          }
        }
      )

      expect(target.metadata[:labels]).to be_a(Hash)
      expect(target.metadata.dig(:labels, :platform)).to eq('youtube')

      # Clean up
      target.delete
    end
  end

  describe 'finding a simulcast target' do
    let(:target) { client.create_simulcast_target(test_rtmp_url) }
    after do
      target.delete
    rescue StandardError
      nil
    end

    it 'retrieves simulcast target by ID' do
      found = client.simulcast_target(target.id)

      expect(found).to be_a(PugClient::Resources::SimulcastTarget)
      expect(found.id).to eq(target.id)
      expect(found.namespace_id).to eq(namespace_id)
      expect(found.url).to eq(test_rtmp_url)
    end

    it 'raises ResourceNotFound for non-existent simulcast target' do
      expect do
        client.simulcast_target('non-existent-target-12345')
      end.to raise_error(PugClient::ResourceNotFound, /SimulcastTarget/)
    end
  end

  describe 'listing simulcast targets' do
    before do
      # Ensure at least one simulcast target exists
      @test_target = client.create_simulcast_target(
        test_rtmp_url,
        metadata: { labels: { test: 'list' } }
      )
    end

    after do
      @test_target.delete
    rescue StandardError
      nil
    end

    it 'lists simulcast targets with pagination' do
      targets = client.simulcast_targets.first(5)

      expect(targets).to be_an(Array)
      expect(targets.length).to be <= 5
      targets.each do |target|
        expect(target).to be_a(PugClient::Resources::SimulcastTarget)
        expect(target.id).to be_a(String)
        expect(target.namespace_id).to eq(namespace_id)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.simulcast_targets

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::SimulcastTarget)
    end
  end

  describe 'updating a simulcast target' do
    let(:target) { client.create_simulcast_target(test_rtmp_url) }
    after do
      target.delete
    rescue StandardError
      nil
    end

    it 'updates simulcast target metadata via dirty tracking' do
      test_value = 'updated-status'
      target.metadata[:labels] ||= {}
      target.metadata[:labels][:status] = test_value

      expect(target.changed?).to be true
      expect(target.save).to be true
      expect(target.changed?).to be false

      # Verify the change persisted
      reloaded = client.simulcast_target(target.id)
      expect(reloaded.metadata.dig(:labels, :status)).to eq(test_value)
    end

    it 'does not save when no changes made' do
      expect(target.changed?).to be false
      expect(target.save).to be true
    end
  end

  describe 'reloading a simulcast target' do
    let(:target) { client.create_simulcast_target(test_rtmp_url) }
    after do
      target.delete
    rescue StandardError
      nil
    end

    it 'discards local changes and reloads from API' do
      # Make local change without saving
      target.metadata[:labels] ||= {}
      target.metadata[:labels][:temp] = 'should-be-discarded'
      expect(target.changed?).to be true

      # Reload discards the change
      target.reload
      expect(target.changed?).to be false
      expect(target.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'deleting a simulcast target' do
    it 'deletes a simulcast target' do
      target = client.create_simulcast_target(test_rtmp_url)
      target_id = target.id

      expect(target.delete).to be true

      # Verify simulcast target is gone
      expect do
        client.simulcast_target(target_id)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'freezes simulcast target object after deletion' do
      target = client.create_simulcast_target(test_rtmp_url)
      target.delete

      expect(target.frozen?).to be true
      expect do
        target.metadata[:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe 'simulcast target relationships' do
    let(:target) { client.create_simulcast_target(test_rtmp_url) }
    after do
      target.delete
    rescue StandardError
      nil
    end

    it 'accesses parent namespace' do
      namespace = target.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'provides URL accessor' do
      expect(target.url).to eq(test_rtmp_url)
    end
  end
end
