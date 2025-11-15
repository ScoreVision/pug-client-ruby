# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::SimulcastTarget do
  include_context 'resource spec client'

  let(:target_id) { 'target-123' }
  let(:rtmp_url) { 'rtmp://youtube.com/live/streamkey' }

  let(:api_response) do
    build_api_response(
      type: 'SimulcastTargets',
      id: target_id,
      attributes: {
        'url' => rtmp_url,
        **build_metadata_timestamps,
        'metadata' => {
          'labels' => { 'platform' => 'youtube' }
        }
      }
    )
  end

  it_behaves_like 'a findable resource', 'simulcasttargets', :target_id

  it_behaves_like 'a listable resource', 'simulcasttargets'

  describe '.create' do
    it 'creates a new simulcast target with URL' do
      expected_body = {
        data: {
          type: 'SimulcastTargets',
          attributes: {
            url: rtmp_url
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/simulcasttargets", expected_body)
        .and_return(api_response)

      target = described_class.create(client, namespace_id, rtmp_url)

      expect(target).to be_a(described_class)
      expect(target.id).to eq(target_id)
      expect(target.namespace_id).to eq(namespace_id)
      expect(target.url).to eq(rtmp_url)
    end

    it 'creates a simulcast target with metadata' do
      metadata = { labels: { platform: 'youtube', event: 'game-day' } }

      expected_body = {
        data: {
          type: 'SimulcastTargets',
          attributes: {
            url: rtmp_url,
            metadata: metadata
          }
        }
      }

      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/simulcasttargets", expected_body)
        .and_return(api_response)

      target = described_class.create(client, namespace_id, rtmp_url, metadata: metadata)

      expect(target).to be_a(described_class)
      expect(target.metadata).to eq(labels: { platform: 'youtube' })
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:post)
        .with("namespaces/#{namespace_id}/simulcasttargets", anything)
        .and_raise(StandardError.new('API error'))

      expect do
        described_class.create(client, namespace_id, rtmp_url)
      end.to raise_error(PugClient::NetworkError, /API error/)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API data with namespace_id' do
      target = described_class.from_api_data(client, api_response, _namespace_id: namespace_id)

      expect(target).to be_a(described_class)
      expect(target.id).to eq(target_id)
      expect(target.namespace_id).to eq(namespace_id)
    end
  end

  # Shared resource instance for instance method tests
  let(:resource_instance) do
    described_class.new(client: client, namespace_id: namespace_id, attributes: api_response)
  end

  it_behaves_like 'a saveable resource', 'simulcasttargets', :target_id do
    let(:mutation) { -> { resource_instance.url = 'rtmp://new-url.com/stream/key' } }
    let(:expected_patch) do
      [{ op: 'replace', path: '/url', value: 'rtmp://new-url.com/stream/key' }]
    end
  end

  it_behaves_like 'a reloadable resource', 'simulcasttargets', :target_id do
    let(:updated_response) do
      api_response.dup.tap { |resp| resp[:data][:attributes]['url'] = 'rtmp://new-url.com/stream/key' }
    end
  end

  it_behaves_like 'a deletable resource', 'simulcasttargets', :target_id

  it_behaves_like 'has namespace association'

  describe '#url' do
    it 'returns the RTMP URL' do
      expect(resource_instance.url).to eq(rtmp_url)
    end
  end

  describe '#inspect' do
    it 'includes id, url (truncated), and changed status' do
      expect(resource_instance.inspect).to match(/SimulcastTarget/)
      expect(resource_instance.inspect).to include(target_id)
      expect(resource_instance.inspect).to include('rtmp://youtube')
      expect(resource_instance.inspect).to include('changed=false')
    end

    it 'truncates long URLs' do
      long_url = 'rtmp://' + 'a' * 100
      target_with_long_url = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          data: {
            id: target_id,
            type: 'SimulcastTargets',
            attributes: { 'url' => long_url }
          }
        }
      )

      inspect_output = target_with_long_url.inspect
      expect(inspect_output).to include('...')
      expect(inspect_output.scan(%r{rtmp://a+}).first.length).to be <= 53 # 50 chars + '...'
    end
  end

  it_behaves_like 'has dirty tracking' do
    let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'active' } }
  end
end
