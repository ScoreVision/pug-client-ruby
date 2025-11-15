# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Resources::Campaign do
  let(:client) { PugClient::Client.new(namespace: 'test-namespace', client_id: 'test_id', client_secret: 'test_secret') }
  let(:namespace_id) { 'test-namespace' }
  let(:campaign_slug) { 'summer-2024' }
  let(:campaign_id) { 'campaign-uuid-123' }

  let(:api_response) do
    build_api_response(
      type: 'campaigns',
      id: campaign_id,
      attributes: {
        'slug' => campaign_slug,
        **build_metadata_timestamps
      }
    )
  end

  describe '.find' do
    it 'fetches campaign by slug' do
      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/campaigns/#{campaign_slug}", {})
        .and_return(api_response)

      campaign = described_class.find(client, namespace_id, campaign_slug)

      expect(campaign).to be_a(described_class)
      expect(campaign.id).to eq(campaign_id)
      expect(campaign.slug).to eq(campaign_slug)
      expect(campaign.namespace_id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound when campaign does not exist' do
      stub_404_error(client, :get, "namespaces/#{namespace_id}/campaigns/#{campaign_slug}")

      expect do
        described_class.find(client, namespace_id, campaign_slug)
      end.to raise_error(PugClient::ResourceNotFound, /Campaign.*#{campaign_slug}/)
    end

    it 'raises NetworkError for other API failures' do
      stub_network_error(client, :get, "namespaces/#{namespace_id}/campaigns/#{campaign_slug}",
                         message: 'Connection failed')

      expect do
        described_class.find(client, namespace_id, campaign_slug)
      end.to raise_error(PugClient::NetworkError, /Connection failed/)
    end
  end

  it_behaves_like 'a listable resource', 'campaigns'

  describe '.create' do
    it 'creates campaign with minimal attributes' do
      campaign_name = 'Test Campaign'
      api_response = {
        data: {
          id: campaign_id,
          type: 'campaigns',
          attributes: {
            'name' => campaign_name,
            'slug' => campaign_slug
          }
        }
      }

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/campaigns",
        {
          data: {
            type: 'campaigns',
            attributes: {
              name: campaign_name,
              slug: campaign_slug
            }
          }
        }
      ).and_return(api_response)

      campaign = described_class.create(client, namespace_id, campaign_name, campaign_slug)

      expect(campaign).to be_a(described_class)
      expect(campaign.slug).to eq(campaign_slug)
      expect(campaign.namespace_id).to eq(namespace_id)
    end

    it 'creates campaign with all optional attributes' do
      campaign_name = 'Summer 2024 Campaign'
      start_time = Time.utc(2024, 6, 1, 0, 0, 0)
      end_time = Time.utc(2024, 8, 31, 23, 59, 59)

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/campaigns",
        {
          data: {
            type: 'campaigns',
            attributes: {
              name: campaign_name,
              slug: campaign_slug,
              prerollVideoId: 'video-123',
              postrollVideoId: 'video-456',
              startTime: '2024-06-01T00:00:00Z',
              endTime: '2024-08-31T23:59:59Z',
              metadata: {
                labels: { season: 'summer' },
                annotations: { description: 'Summer campaign' }
              }
            }
          }
        }
      ).and_return({
                     data: {
                       id: campaign_id,
                       type: 'campaigns',
                       attributes: {
                         'name' => campaign_name,
                         'slug' => campaign_slug
                       }
                     }
                   })

      campaign = described_class.create(
        client,
        namespace_id,
        campaign_name,
        campaign_slug,
        preroll_video_id: 'video-123',
        postroll_video_id: 'video-456',
        start_time: start_time,
        end_time: end_time,
        metadata: {
          labels: { season: 'summer' },
          annotations: { description: 'Summer campaign' }
        }
      )

      expect(campaign).to be_a(described_class)
    end

    it 'converts Time objects to ISO8601' do
      campaign_name = 'Test Campaign'
      start_time = Time.utc(2024, 1, 1, 12, 0, 0)

      expect(client).to receive(:post).with(
        "namespaces/#{namespace_id}/campaigns",
        hash_including(
          data: hash_including(
            attributes: hash_including(
              name: campaign_name,
              slug: campaign_slug,
              startTime: '2024-01-01T12:00:00Z'
            )
          )
        )
      ).and_return({
                     id: campaign_id,
                     attributes: {
                       name: campaign_name,
                       slug: campaign_slug
                     }
                   })

      described_class.create(client, namespace_id, campaign_name, campaign_slug, start_time: start_time)
    end

    it 'raises NetworkError on API failure' do
      expect(client).to receive(:post)
        .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect do
        described_class.create(client, namespace_id, 'Test Campaign', campaign_slug)
      end.to raise_error(PugClient::NetworkError)
    end
  end

  describe '.from_api_data' do
    it 'instantiates from API response data' do
      api_data = {
        data: {
          id: campaign_id,
          type: 'campaigns',
          attributes: {
            'slug' => campaign_slug,
            'createdAt' => '2024-01-01T00:00:00Z'
          }
        }
      }

      campaign = described_class.from_api_data(
        client,
        api_data,
        _namespace_id: namespace_id
      )

      expect(campaign).to be_a(described_class)
      expect(campaign.id).to eq(campaign_id)
      expect(campaign.slug).to eq(campaign_slug)
      expect(campaign.namespace_id).to eq(namespace_id)
    end
  end

  # Shared resource instance for instance method tests
  let(:resource_instance) do
    described_class.new(
      client: client,
      namespace_id: namespace_id,
      attributes: {
        id: campaign_id,
        slug: campaign_slug,
        metadata: { labels: { env: 'prod' } }
      }
    )
  end

  it_behaves_like 'a saveable resource', 'campaigns', :campaign_slug do
    let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'active' } }
    let(:expected_patch) do
      [{ op: 'add', path: '/metadata/labels/status', value: 'active' }]
    end
  end

  describe '#save' do
    let(:campaign) { resource_instance }

    it 'uses slug in URL' do
      campaign.metadata[:labels][:test] = 'value'

      expect(client).to receive(:patch).with(
        "namespaces/#{namespace_id}/campaigns/#{campaign_slug}",
        anything
      ).and_return({ data: { id: campaign_id, attributes: {} } })

      campaign.save
    end

    it 'handles multiple changes' do
      campaign.preroll_video_id = 'new-video-123'
      campaign.metadata[:labels][:version] = 'v2'

      expect(client).to receive(:patch).with(
        "namespaces/#{namespace_id}/campaigns/#{campaign_slug}",
        hash_including(
          data: array_including(
            hash_including(op: 'add', path: '/prerollVideoId'),
            hash_including(op: 'add', path: '/metadata/labels/version')
          )
        )
      ).and_return({ data: { id: campaign_id, attributes: {} } })

      campaign.save
    end
  end

  it_behaves_like 'a reloadable resource', 'campaigns', :campaign_slug do
    let(:updated_response) do
      api_response.dup.tap { |resp| resp[:data][:attributes]['metadata'] = { 'labels' => { 'env' => 'staging' } } }
    end
  end

  describe '#reload' do
    let(:campaign) { resource_instance }

    it 'uses slug in URL' do
      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/campaigns/#{campaign_slug}")
        .and_return({ data: { id: campaign_id, attributes: {} } })

      campaign.reload
    end
  end

  it_behaves_like 'a deletable resource', 'campaigns', :campaign_slug

  describe '#delete' do
    let(:campaign) { resource_instance }

    it 'uses slug in URL' do
      expect(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/campaigns/#{campaign_slug}")
        .and_return(true)

      campaign.delete
    end
  end

  it_behaves_like 'has namespace association'

  describe '#preroll_video' do
    it 'fetches preroll video when preroll_video_id is set' do
      campaign = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: campaign_id,
          slug: campaign_slug,
          preroll_video_id: 'video-123'
        }
      )

      video_data = { id: 'video-123', attributes: {} }

      expect(PugClient::Resources::Video).to receive(:find)
        .with(client, namespace_id, 'video-123')
        .and_return(PugClient::Resources::Video.new(
                      client: client,
                      namespace_id: namespace_id,
                      attributes: video_data
                    ))

      video = campaign.preroll_video

      expect(video).to be_a(PugClient::Resources::Video)
      expect(video.id).to eq('video-123')
    end

    it 'returns nil when preroll_video_id is not set' do
      campaign = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: campaign_id, slug: campaign_slug }
      )

      expect(campaign.preroll_video).to be_nil
    end
  end

  describe '#postroll_video' do
    it 'fetches postroll video when postroll_video_id is set' do
      campaign = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: campaign_id,
          slug: campaign_slug,
          postroll_video_id: 'video-456'
        }
      )

      video_data = { id: 'video-456', attributes: {} }

      expect(PugClient::Resources::Video).to receive(:find)
        .with(client, namespace_id, 'video-456')
        .and_return(PugClient::Resources::Video.new(
                      client: client,
                      namespace_id: namespace_id,
                      attributes: video_data
                    ))

      video = campaign.postroll_video

      expect(video).to be_a(PugClient::Resources::Video)
      expect(video.id).to eq('video-456')
    end

    it 'returns nil when postroll_video_id is not set' do
      campaign = described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: { id: campaign_id, slug: campaign_slug }
      )

      expect(campaign.postroll_video).to be_nil
    end
  end

  describe 'read-only attributes' do
    let(:campaign) do
      described_class.new(
        client: client,
        namespace_id: namespace_id,
        attributes: {
          id: campaign_id,
          slug: campaign_slug,
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-02T00:00:00Z'
        }
      )
    end

    it 'prevents modification of id' do
      expect do
        campaign.id = 'new-id'
      end.to raise_error(PugClient::ValidationError, /read-only.*id/i)
    end

    it 'prevents modification of created_at' do
      expect do
        campaign.created_at = '2024-02-01T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /read-only.*created_at/i)
    end

    it 'prevents modification of updated_at' do
      expect do
        campaign.updated_at = '2024-02-01T00:00:00Z'
      end.to raise_error(PugClient::ValidationError, /read-only.*updated_at/i)
    end

    it 'allows reading read-only attributes' do
      expect(campaign.id).to eq(campaign_id)
      expect(campaign.created_at).to eq('2024-01-01T00:00:00Z')
      expect(campaign.updated_at).to eq('2024-01-02T00:00:00Z')
    end

    it 'allows modification of other attributes' do
      expect { campaign.preroll_video_id = 'new-video' }.not_to raise_error
      expect { campaign.metadata = { labels: { test: 'value' } } }.not_to raise_error
    end
  end

  it_behaves_like 'has dirty tracking' do
    let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'active' } }
  end

  describe 'dirty tracking integration' do
    let(:campaign) { resource_instance }

    it 'generates correct patch operations for multiple changes' do
      campaign.preroll_video_id = 'video-789'
      campaign.metadata[:labels][:version] = 'v2'

      operations = campaign.generate_patch_operations

      expect(operations).to include(
        hash_including(op: 'add', path: '/prerollVideoId', value: 'video-789')
      )
      expect(operations).to include(
        hash_including(op: 'add', path: '/metadata/labels/version', value: 'v2')
      )
    end
  end

  describe '#inspect' do
    it 'provides human-readable representation' do
      expect(resource_instance.inspect).to include('Campaign')
      expect(resource_instance.inspect).to include(campaign_id)
      expect(resource_instance.inspect).to include(campaign_slug)
    end

    it 'shows changed state' do
      campaign = resource_instance
      expect(campaign.inspect).to include('changed=false')

      campaign.metadata = { labels: { test: 'value' } }

      expect(campaign.inspect).to include('changed=true')
    end
  end
end
