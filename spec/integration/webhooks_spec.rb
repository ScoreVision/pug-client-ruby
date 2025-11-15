# frozen_string_literal: true

require 'spec_helper'
require 'support/integration_helper'

RSpec.describe 'Webhooks Integration', :vcr, :integration do
  let(:client) { create_test_client }
  let(:namespace_id) { ENV['PUG_NAMESPACE'] }
  let(:test_webhook_url) { 'https://webhook.example.com/events/test-webhook' }
  let(:test_actions) { ['video.ready', 'video.deleted'] }

  describe 'creating a webhook' do
    it 'creates a webhook with URL and actions' do
      webhook = client.create_webhook(test_webhook_url, test_actions)

      expect(webhook).to be_a(PugClient::Resources::Webhook)
      expect(webhook.id).to be_a(String)
      expect(webhook.namespace_id).to eq(namespace_id)
      expect(webhook.url).to eq(test_webhook_url)
      expect(webhook.actions).to eq(test_actions)

      # Clean up
      webhook.delete
    end

    it 'creates a webhook with metadata' do
      webhook = client.create_webhook(
        test_webhook_url,
        test_actions,
        metadata: {
          labels: {
            environment: 'test',
            service: 'notifications'
          }
        }
      )

      expect(webhook.metadata[:labels]).to be_a(Hash)
      expect(webhook.metadata.dig(:labels, :environment)).to eq('test')

      # Clean up
      webhook.delete
    end

    it 'creates a webhook with different action types' do
      actions = ['livestream.published', 'livestream.unpublished']
      webhook = client.create_webhook(test_webhook_url, actions)

      expect(webhook.actions).to eq(actions)

      # Clean up
      webhook.delete
    end
  end

  describe 'finding a webhook' do
    let(:webhook) { client.create_webhook(test_webhook_url, test_actions) }
    after do
      webhook.delete
    rescue StandardError
      nil
    end

    it 'retrieves webhook by ID' do
      found = client.webhook(webhook.id)

      expect(found).to be_a(PugClient::Resources::Webhook)
      expect(found.id).to eq(webhook.id)
      expect(found.namespace_id).to eq(namespace_id)
      expect(found.url).to eq(test_webhook_url)
      expect(found.actions).to eq(test_actions)
    end

    it 'raises ResourceNotFound for non-existent webhook' do
      expect do
        client.webhook('non-existent-webhook-12345')
      end.to raise_error(PugClient::ResourceNotFound, /Webhook/)
    end
  end

  describe 'listing webhooks' do
    before do
      # Ensure at least one webhook exists
      @test_webhook = client.create_webhook(
        test_webhook_url,
        test_actions,
        metadata: { labels: { test: 'list' } }
      )
    end

    after do
      @test_webhook.delete
    rescue StandardError
      nil
    end

    it 'lists webhooks with pagination' do
      webhooks = client.webhooks.first(5)

      expect(webhooks).to be_an(Array)
      expect(webhooks.length).to be <= 5
      webhooks.each do |webhook|
        expect(webhook).to be_a(PugClient::Resources::Webhook)
        expect(webhook.id).to be_a(String)
        expect(webhook.namespace_id).to eq(namespace_id)
      end
    end

    it 'supports lazy enumeration' do
      enumerator = client.webhooks

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
      expect(enumerator.first).to be_a(PugClient::Resources::Webhook)
    end
  end

  describe 'updating a webhook' do
    let(:webhook) { client.create_webhook(test_webhook_url, test_actions) }
    after do
      webhook.delete
    rescue StandardError
      nil
    end

    it 'updates webhook metadata via dirty tracking' do
      test_value = 'updated-status'
      webhook.metadata[:labels] ||= {}
      webhook.metadata[:labels][:status] = test_value

      expect(webhook.changed?).to be true
      expect(webhook.save).to be true
      expect(webhook.changed?).to be false

      # Verify the change persisted
      reloaded = client.webhook(webhook.id)
      expect(reloaded.metadata.dig(:labels, :status)).to eq(test_value)
    end

    it 'does not save when no changes made' do
      expect(webhook.changed?).to be false
      expect(webhook.save).to be true
    end
  end

  describe 'reloading a webhook' do
    let(:webhook) { client.create_webhook(test_webhook_url, test_actions) }
    after do
      webhook.delete
    rescue StandardError
      nil
    end

    it 'discards local changes and reloads from API' do
      # Make local change without saving
      webhook.metadata[:labels] ||= {}
      webhook.metadata[:labels][:temp] = 'should-be-discarded'
      expect(webhook.changed?).to be true

      # Reload discards the change
      webhook.reload
      expect(webhook.changed?).to be false
      expect(webhook.metadata.dig(:labels, :temp)).to be_nil
    end
  end

  describe 'deleting a webhook' do
    it 'deletes a webhook' do
      webhook = client.create_webhook(test_webhook_url, test_actions)
      webhook_id = webhook.id

      expect(webhook.delete).to be true

      # Verify webhook is gone
      expect do
        client.webhook(webhook_id)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'freezes webhook object after deletion' do
      webhook = client.create_webhook(test_webhook_url, test_actions)
      webhook.delete

      expect(webhook.frozen?).to be true
      expect do
        webhook.metadata[:test] = 'value'
      end.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe 'webhook relationships' do
    let(:webhook) { client.create_webhook(test_webhook_url, test_actions) }
    after do
      webhook.delete
    rescue StandardError
      nil
    end

    it 'accesses parent namespace' do
      namespace = webhook.namespace

      expect(namespace).to be_a(PugClient::Resources::Namespace)
      expect(namespace.id).to eq(namespace_id)
    end

    it 'provides URL accessor' do
      expect(webhook.url).to eq(test_webhook_url)
    end

    it 'provides actions accessor' do
      expect(webhook.actions).to eq(test_actions)
    end
  end
end
