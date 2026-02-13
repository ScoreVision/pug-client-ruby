# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::PatchGenerator do
  describe '.generate' do
    context 'with add operations' do
      it 'generates add operation for simple value' do
        changes = [
          { type: :add, path: [:new_key], value: 'new_value' }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'add',
                                  path: '/newKey',
                                  value: 'new_value'
                                }
                              ])
      end

      it 'generates add operation for nested path' do
        changes = [
          { type: :add, path: %i[metadata labels new_key], value: 'value' }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'add',
                                  path: '/metadata/labels/newKey',
                                  value: 'value'
                                }
                              ])
      end

      it 'converts snake_case keys to camelCase in paths' do
        changes = [
          { type: :add, path: [:my_new_key], value: 'value' }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:path]).to eq('/myNewKey')
      end

      it 'converts snake_case keys to camelCase in hash values' do
        changes = [
          { type: :add, path: [:metadata], value: { my_key: 'value' } }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq({ myKey: 'value' })
      end

      it 'handles array values' do
        changes = [
          { type: :add, path: [:tags], value: %w[tag1 tag2] }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq(%w[tag1 tag2])
      end

      it 'handles nil values' do
        changes = [
          { type: :add, path: [:nullable_field], value: nil }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to be_nil
      end
    end

    context 'with replace operations' do
      it 'generates replace operation for simple value' do
        changes = [
          { type: :replace, path: [:status], old_value: 'old', new_value: 'new' }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'replace',
                                  path: '/status',
                                  value: 'new'
                                }
                              ])
      end

      it 'generates replace operation for nested path' do
        changes = [
          { type: :replace, path: %i[metadata labels status], old_value: 'processing', new_value: 'ready' }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'replace',
                                  path: '/metadata/labels/status',
                                  value: 'ready'
                                }
                              ])
      end

      it 'converts snake_case keys to camelCase in paths' do
        changes = [
          { type: :replace, path: [:my_field], old_value: 'old', new_value: 'new' }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:path]).to eq('/myField')
      end

      it 'converts snake_case keys to camelCase in hash values' do
        changes = [
          { type: :replace, path: [:metadata], old_value: {}, new_value: { my_key: 'value' } }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq({ myKey: 'value' })
      end
    end

    context 'with remove operations' do
      it 'generates remove operation' do
        changes = [
          { type: :remove, path: [:old_key] }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'remove',
                                  path: '/oldKey'
                                }
                              ])
      end

      it 'generates remove operation for nested path' do
        changes = [
          { type: :remove, path: %i[metadata labels old_key] }
        ]

        patches = described_class.generate(changes)

        expect(patches).to eq([
                                {
                                  op: 'remove',
                                  path: '/metadata/labels/oldKey'
                                }
                              ])
      end

      it 'does not include value in remove operation' do
        changes = [
          { type: :remove, path: [:old_key] }
        ]

        patches = described_class.generate(changes)

        expect(patches.first).not_to have_key(:value)
      end
    end

    context 'with TrackedHash values' do
      it 'converts TrackedHash to regular hash' do
        tracked = PugClient::TrackedHash.new({ my_key: 'value' })
        changes = [
          { type: :add, path: [:metadata], value: tracked }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq({ myKey: 'value' })
      end

      it 'handles nested TrackedHash' do
        tracked = PugClient::TrackedHash.new({
                                               labels: PugClient::TrackedHash.new({ my_key: 'value' })
                                             })
        changes = [
          { type: :add, path: [:metadata], value: tracked }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq({
                                              labels: { myKey: 'value' }
                                            })
      end
    end

    context 'with multiple operations' do
      it 'generates multiple patches' do
        changes = [
          { type: :add, path: [:new_key], value: 'new' },
          { type: :replace, path: [:status], old_value: 'old', new_value: 'updated' },
          { type: :remove, path: [:old_key] }
        ]

        patches = described_class.generate(changes)

        expect(patches.size).to eq(3)
        expect(patches[0][:op]).to eq('add')
        expect(patches[1][:op]).to eq('replace')
        expect(patches[2][:op]).to eq('remove')
      end

      it 'maintains order of operations' do
        changes = [
          { type: :remove, path: [:a] },
          { type: :add, path: [:b], value: 'b' },
          { type: :replace, path: [:c], old_value: 'old', new_value: 'new' }
        ]

        patches = described_class.generate(changes)

        expect(patches.map { |p| p[:op] }).to eq(%w[remove add replace])
      end
    end

    context 'with complex nested structures' do
      it 'handles deeply nested paths' do
        changes = [
          { type: :replace, path: %i[level1 level2 level3 deep_key], old_value: 'old', new_value: 'new' }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:path]).to eq('/level1/level2/level3/deepKey')
      end

      it 'handles complex hash values with nested structures' do
        changes = [
          {
            type: :add,
            path: [:metadata],
            value: {
              labels: { my_label: 'value' },
              annotations: { my_annotation: 'note' }
            }
          }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq({
                                              labels: { myLabel: 'value' },
                                              annotations: { myAnnotation: 'note' }
                                            })
      end

      it 'handles arrays of hashes' do
        changes = [
          {
            type: :add,
            path: [:items],
            value: [
              { item_id: 1, item_name: 'First' },
              { item_id: 2, item_name: 'Second' }
            ]
          }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq([
                                              { itemId: 1, itemName: 'First' },
                                              { itemId: 2, itemName: 'Second' }
                                            ])
      end
    end

    context 'with camelCase conversion for multi-word attributes' do
      it 'converts multi-word snake_case to camelCase' do
        changes = [
          { type: :add, path: [:simulcast_targets], value: [{ stream_url: 'rtmp://example.com' }] }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:path]).to eq('/simulcastTargets')
        expect(patches.first[:value]).to eq([{ streamUrl: 'rtmp://example.com' }])
      end
    end

    context 'edge cases' do
      it 'handles empty changes array' do
        patches = described_class.generate([])
        expect(patches).to eq([])
      end

      it 'handles single-level paths' do
        changes = [
          { type: :add, path: [:key], value: 'value' }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:path]).to eq('/key')
      end

      it 'handles numeric values' do
        changes = [
          { type: :add, path: [:count], value: 42 }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to eq(42)
      end

      it 'handles boolean values' do
        changes = [
          { type: :add, path: [:enabled], value: true }
        ]

        patches = described_class.generate(changes)

        expect(patches.first[:value]).to be true
      end
    end

    context 'API format compliance' do
      it 'generates RFC 6902 compliant operations' do
        changes = [
          { type: :replace, path: %i[metadata labels status], old_value: 'processing', new_value: 'ready' }
        ]

        patches = described_class.generate(changes)
        patch = patches.first

        # RFC 6902 requires 'op' and 'path'
        expect(patch).to have_key(:op)
        expect(patch).to have_key(:path)

        # Path must start with /
        expect(patch[:path]).to start_with('/')

        # Op must be a valid operation
        expect(%w[add remove replace move copy test]).to include(patch[:op])
      end
    end
  end
end
