# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'Namespaces Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }

  describe 'finding a namespace' do
    it 'retrieves namespace by ID' do
      namespace = client.namespace(namespace_id)

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound for non-existent namespace' do
      expect do
        client.namespace('non-existent-namespace-12345')
      end.to raise_error(PugClient::ResourceNotFound, /Namespace/)
    end
  end

  describe 'listing namespaces' do
    it 'lists all namespaces with pagination' do
      namespaces = client.namespaces.first(5)

      expect(namespaces).to be_an(Array)
      expect(namespaces.length).to be <= 5
      namespaces.each do |namespace|
        expect(namespace).to be_a(PugClient::Resources::Namespace)
        expect(namespace.id).to be_a(String)
      end
    end

    it 'lists user namespaces' do
      namespaces = client.user_namespaces.first(10)

      expect(namespaces).to be_an(Array)
      namespaces.each do |namespace|
        expect(namespace).to be_a(PugClient::Resources::Namespace)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.namespaces

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::Namespace)
    end
  end

  describe 'reloading a namespace' do
    it 'discards local changes and reloads from API' do
      namespace = client.namespace(namespace_id)
      namespace.metadata.dup

      # Make local change without saving
      namespace.metadata[:labels] ||= {}
      namespace.metadata[:labels][:temp] = 'should-be-discarded'
      expect(namespace.changed?).to be true

      # Reload discards the change
      namespace.reload
      expect(namespace.changed?).to be false
      expect(namespace.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'namespace resource relationships' do
    it 'accesses videos through namespace' do
      namespace = client.namespace(namespace_id)
      videos = namespace.videos.first(3)

      expect(videos).to be_an(Array)
      videos.each do |video|
        expect(video).to be_a(PugClient::Resources::Video)
        expect(video.namespace_id).to eq(namespace_id)
      end
    end

    it 'accesses live streams through namespace' do
      namespace = client.namespace(namespace_id)
      streams = namespace.livestreams.first(3)

      expect(streams).to be_an(Array)
      streams.each do |stream|
        expect(stream).to be_a(PugClient::Resources::LiveStream)
        expect(stream.namespace_id).to eq(namespace_id)
      end
    end
  end
end
