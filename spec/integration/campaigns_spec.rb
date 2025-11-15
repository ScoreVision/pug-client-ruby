# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'Campaigns Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }

  describe 'creating a campaign' do
    it 'creates a campaign with a slug' do
      slug = 'test-campaign-slug'
      campaign = client.create_campaign("Test Campaign #{slug}", slug)

      expect(campaign).to be_a(PugClient::Resources::Campaign)
      expect(campaign.id).to be_a(String)
      expect(campaign.slug).to eq(slug)
      expect(campaign.namespace_id).to eq(namespace_id)

      # Clean up
      campaign.delete
    end

    it 'creates a campaign with metadata' do
      slug = 'test-campaign-metadata'
      campaign = client.create_campaign(
        "Test Campaign #{slug}",
        slug,
        metadata: {
          labels: {
            season: '2025',
            type: 'playoffs'
          }
        }
      )

      expect(campaign.metadata[:labels]).to be_a(Hash)
      expect(campaign.metadata.dig(:labels, :season)).to eq('2025')

      # Clean up
      campaign.delete
    end
  end

  describe 'finding a campaign' do
    let(:campaign) do
      slug = 'test-campaign-find'
      client.create_campaign("Test Campaign #{slug}", slug)
    end
    after do
      campaign.delete
    rescue StandardError
      nil
    end

    it 'retrieves campaign by ID' do
      found = client.campaign(campaign.slug)

      expect(found).to be_a(PugClient::Resources::Campaign)
      expect(found.id).to eq(campaign.id)
      expect(found.slug).to eq(campaign.slug)
      expect(found.namespace_id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound for non-existent campaign' do
      expect do
        client.campaign('non-existent-campaign-12345')
      end.to raise_error(PugClient::ResourceNotFound, /Campaign/)
    end
  end

  describe 'listing campaigns' do
    before do
      # Ensure at least one campaign exists
      slug = 'test-campaign-list'
      @test_campaign = client.create_campaign(
        "Test Campaign #{slug}",
        slug,
        metadata: { labels: { test: 'list' } }
      )
    end

    after do
      @test_campaign.delete
    rescue StandardError
      nil
    end

    it 'lists campaigns with pagination' do
      campaigns = client.campaigns.first(5)

      expect(campaigns).to be_an(Array)
      expect(campaigns.length).to be <= 5
      campaigns.each do |campaign|
        expect(campaign).to be_a(PugClient::Resources::Campaign)
        expect(campaign.id).to be_a(String)
        expect(campaign.slug).to be_a(String)
        expect(campaign.namespace_id).to eq(namespace_id)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.campaigns

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::Campaign)
    end
  end

  describe 'updating a campaign' do
    let(:campaign) do
      slug = 'test-campaign-update'
      client.create_campaign("Test Campaign #{slug}", slug)
    end
    after do
      campaign.delete
    rescue StandardError
      nil
    end

    it 'updates campaign metadata via dirty tracking' do
      test_value = 'updated-status'
      campaign.metadata[:labels] ||= {}
      campaign.metadata[:labels][:status] = test_value

      expect(campaign.changed?).to be true
      expect(campaign.save).to be true
      expect(campaign.changed?).to be false

      # Verify the change persisted
      reloaded = client.campaign(campaign.slug)
      expect(reloaded.metadata.dig(:labels, :status)).to eq(test_value)
    end

    it 'does not save when no changes made' do
      expect(campaign.changed?).to be false
      expect(campaign.save).to be true
    end
  end

  describe 'reloading a campaign' do
    let(:campaign) do
      slug = 'test-campaign-reload'
      client.create_campaign("Test Campaign #{slug}", slug)
    end
    after do
      campaign.delete
    rescue StandardError
      nil
    end

    it 'discards local changes and reloads from API' do
      # Make local change without saving
      campaign.metadata[:labels] ||= {}
      campaign.metadata[:labels][:temp] = 'should-be-discarded'
      expect(campaign.changed?).to be true

      # Reload discards the change
      campaign.reload
      expect(campaign.changed?).to be false
      expect(campaign.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'deleting a campaign' do
    it 'deletes a campaign' do
      slug = 'test-campaign-delete'
      campaign = client.create_campaign("Test Campaign #{slug}", slug)
      campaign_slug = campaign.slug

      expect(campaign.delete).to be true

      # Verify campaign is gone
      expect do
        client.campaign(campaign_slug)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'freezes campaign object after deletion' do
      slug = 'test-campaign-freeze'
      campaign = client.create_campaign("Test Campaign #{slug}", slug)
      campaign.delete

      expect(campaign.frozen?).to be true
      expect do
        campaign.metadata[:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe 'campaign relationships' do
    let(:campaign) do
      slug = 'test-campaign-relationships'
      client.create_campaign("Test Campaign #{slug}", slug)
    end
    after do
      campaign.delete
    rescue StandardError
      nil
    end

    it 'accesses parent namespace' do
      namespace = campaign.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'provides slug accessor' do
      expect(campaign.slug).to be_a(String)
      expect(campaign.slug).to eq(campaign.slug)
    end
  end
end
