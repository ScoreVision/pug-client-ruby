# frozen_string_literal: true

require 'spec_helper'

# Define test resource class at module level to avoid constant warnings
class TestResource < PugClient::Resource
  READ_ONLY_ATTRIBUTES = %i[id created_at].freeze
end

RSpec.describe PugClient::Resource do
  let(:test_resource_class) { TestResource }
  let(:client) { double('Client') }

  describe '#initialize' do
    it 'initializes with client and attributes' do
      resource = test_resource_class.new(
        client: client,
        attributes: { id: '123', name: 'Test' }
      )

      expect(resource.client).to eq(client)
      expect(resource.id).to eq('123')
    end

    it 'starts with clean state (not dirty)' do
      resource = test_resource_class.new(
        client: client,
        attributes: { id: '123' }
      )

      expect(resource.changed?).to be false
    end
  end

  describe '#load_attributes' do
    it 'converts camelCase to snake_case' do
      resource = test_resource_class.new(
        client: client,
        attributes: { 'startedAt' => '2025-01-01', 'createdAt' => '2025-01-01' }
      )

      expect(resource.started_at).to eq('2025-01-01')
      expect(resource.created_at).to eq('2025-01-01')
    end

    it 'handles JSON:API wrapped format' do
      api_response = {
        data: {
          id: '123',
          type: 'videos',
          attributes: {
            'startedAt' => '2025-01-01',
            'duration' => 120_000
          }
        }
      }

      resource = test_resource_class.new(client: client, attributes: api_response)

      expect(resource.id).to eq('123')
      expect(resource.started_at).to eq('2025-01-01')
      expect(resource.duration).to eq(120_000)
    end

    it 'wraps nested hashes in TrackedHash' do
      resource = test_resource_class.new(
        client: client,
        attributes: { metadata: { labels: { status: 'ready' } } }
      )

      expect(resource.metadata).to be_a(PugClient::TrackedHash)
      expect(resource.metadata[:labels]).to be_a(PugClient::TrackedHash)
    end

    it 'wraps hashes in arrays' do
      resource = test_resource_class.new(
        client: client,
        attributes: { items: [{ id: 1 }, { id: 2 }] }
      )

      expect(resource.items[0]).to be_a(PugClient::TrackedHash)
      expect(resource.items[1]).to be_a(PugClient::TrackedHash)
    end
  end

  describe 'dynamic attribute access' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: { id: '123', status: 'processing', metadata: {} }
      )
    end

    it 'provides getter for attributes' do
      expect(resource.status).to eq('processing')
    end

    it 'provides setter for attributes' do
      resource.status = 'ready'
      expect(resource.status).to eq('ready')
    end

    it 'marks resource as dirty when attribute set' do
      resource.status = 'ready'
      expect(resource.changed?).to be true
    end

    it 'raises NoMethodError for non-existent attributes' do
      expect { resource.nonexistent }.to raise_error(NoMethodError)
    end

    it 'responds to existing attributes' do
      expect(resource).to respond_to(:status)
      expect(resource).to respond_to(:status=)
    end

    it 'does not respond to non-existent attributes' do
      expect(resource).not_to respond_to(:nonexistent)
    end
  end

  describe 'read-only attributes' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: { id: '123', created_at: '2025-01-01' }
      )
    end

    it 'raises error when setting read-only attribute' do
      expect { resource.id = '456' }.to raise_error(
        PugClient::ValidationError,
        /Cannot modify read-only attribute: id/
      )
    end

    it 'raises error for read-only nested attributes' do
      expect { resource.created_at = '2025-01-02' }.to raise_error(
        PugClient::ValidationError,
        /Cannot modify read-only attribute: created_at/
      )
    end

    it 'allows reading read-only attributes' do
      expect(resource.id).to eq('123')
      expect(resource.created_at).to eq('2025-01-01')
    end
  end

  describe 'dirty tracking integration' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: {
          id: '123',
          status: 'processing',
          metadata: { labels: { env: 'prod' } }
        }
      )
    end

    it 'tracks simple attribute changes' do
      resource.status = 'ready'

      expect(resource.changed?).to be true
      changes = resource.changes
      expect(changes.size).to eq(1)
      expect(changes.first[:path]).to eq([:status])
    end

    it 'tracks nested attribute changes' do
      resource.metadata[:labels][:env] = 'staging'

      expect(resource.changed?).to be true
      changes = resource.changes
      expect(changes.size).to eq(1)
      expect(changes.first[:path]).to eq(%i[metadata labels env])
    end

    it 'tracks added nested keys' do
      resource.metadata[:labels][:new_key] = 'value'

      changes = resource.changes
      expect(changes.size).to eq(1)
      expect(changes.first[:type]).to eq(:add)
      expect(changes.first[:path]).to eq(%i[metadata labels new_key])
    end

    it 'clears dirty flag after clearing' do
      resource.status = 'ready'
      expect(resource.changed?).to be true

      resource.clear_dirty!
      expect(resource.changed?).to be false
    end
  end

  describe '#generate_patch_operations' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: { status: 'processing', metadata: { labels: {} } }
      )
    end

    it 'returns empty array when no changes' do
      patches = resource.generate_patch_operations
      expect(patches).to eq([])
    end

    it 'generates patch operations for changes' do
      resource.status = 'ready'

      patches = resource.generate_patch_operations
      expect(patches.size).to eq(1)
      expect(patches.first).to include(
        op: 'replace',
        path: '/status',
        value: 'ready'
      )
    end

    it 'generates patches for nested changes' do
      resource.metadata[:labels][:env] = 'prod'

      patches = resource.generate_patch_operations
      expect(patches.first).to include(
        op: 'add',
        path: '/metadata/labels/env',
        value: 'prod'
      )
    end

    it 'preserves snake_case in patch paths for multi-word attributes' do
      resource = test_resource_class.new(
        client: client,
        attributes: { simulcast_targets: [] }
      )
      resource.simulcast_targets = [{ stream_url: 'rtmp://example.com' }]

      patches = resource.generate_patch_operations
      expect(patches.first).to include(
        op: 'replace',
        path: '/simulcast_targets'
      )
    end
  end

  describe 'abstract methods' do
    let(:resource) do
      test_resource_class.new(client: client, attributes: { id: '123' })
    end

    it 'raises NotImplementedError for save' do
      expect { resource.save }.to raise_error(
        NotImplementedError,
        /must implement #save/
      )
    end

    it 'raises NotImplementedError for reload' do
      expect { resource.reload }.to raise_error(
        NotImplementedError,
        /must implement #reload/
      )
    end

    it 'raises NotImplementedError for delete' do
      expect { resource.delete }.to raise_error(
        NotImplementedError,
        /must implement #delete/
      )
    end
  end

  describe '#freeze_resource!' do
    let(:resource) do
      test_resource_class.new(client: client, attributes: { id: '123', status: 'ready' })
    end

    it 'freezes the resource' do
      resource.freeze_resource!
      expect(resource).to be_frozen
    end

    it 'prevents further modifications' do
      resource.freeze_resource!
      expect { resource.status = 'processing' }.to raise_error(PugClient::ResourceFrozenError)
    end
  end

  describe '#attributes' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: { id: '123', status: 'ready', metadata: {} }
      )
    end

    it 'returns current attributes as hash' do
      attrs = resource.attributes
      expect(attrs).to be_a(Hash)
      expect(attrs[:id]).to eq('123')
      expect(attrs[:status]).to eq('ready')
    end

    it 'returns a copy (not the internal hash)' do
      attrs = resource.attributes
      attrs[:status] = 'modified'
      expect(resource.status).to eq('ready')
    end
  end

  describe '#inspect' do
    let(:resource) do
      test_resource_class.new(client: client, attributes: { id: '123' })
    end

    it 'provides human-readable representation' do
      inspect_str = resource.inspect
      expect(inspect_str).to include('id="123"')
      expect(inspect_str).to include('changed=false')
    end

    it 'shows changed state' do
      resource.mark_dirty!
      inspect_str = resource.inspect
      expect(inspect_str).to include('changed=true')
    end
  end

  describe 'complex scenarios' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: {
          id: '123',
          metadata: {
            labels: { env: 'prod', team: 'video' },
            annotations: { note: 'test' }
          }
        }
      )
    end

    it 'handles multiple changes at different levels' do
      resource.metadata[:labels][:env] = 'staging'
      resource.metadata[:labels][:new_label] = 'value'
      resource.metadata[:annotations][:note] = 'updated'

      changes = resource.changes
      expect(changes.size).to eq(3)

      paths = changes.map { |c| c[:path] }
      expect(paths).to include(
        %i[metadata labels env],
        %i[metadata labels new_label],
        %i[metadata annotations note]
      )
    end

    it 'generates correct patches for multiple changes' do
      resource.metadata[:labels][:env] = 'staging'
      resource.metadata[:labels][:new_label] = 'value'

      patches = resource.generate_patch_operations
      expect(patches.size).to eq(2)

      ops = patches.map { |p| p[:op] }
      expect(ops).to include('replace', 'add')
    end
  end

  describe 'TrackedHash parent reference' do
    let(:resource) do
      test_resource_class.new(
        client: client,
        attributes: { metadata: { labels: {} } }
      )
    end

    it 'TrackedHash marks parent as dirty when modified' do
      expect(resource.changed?).to be false

      resource.metadata[:labels][:new_key] = 'value'

      expect(resource.changed?).to be true
    end

    it 'deeply nested TrackedHash marks parent as dirty' do
      resource.metadata[:labels][:nested] = { deep: 'value' }
      resource.clear_dirty!

      resource.metadata[:labels][:nested][:deep] = 'modified'

      expect(resource.changed?).to be true
    end
  end
end
