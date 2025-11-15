# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::DirtyTracker do
  # Test class that includes the module
  let(:test_class) do
    Class.new do
      include PugClient::DirtyTracker

      attr_accessor :original_attributes, :current_attributes

      def initialize
        @original_attributes = {}
        @current_attributes = {}
        @dirty = false
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#changed?' do
    it 'returns false initially' do
      expect(instance.changed?).to be false
    end

    it 'returns true after mark_dirty!' do
      instance.mark_dirty!
      expect(instance.changed?).to be true
    end

    it 'returns false after clear_dirty!' do
      instance.mark_dirty!
      instance.clear_dirty!
      expect(instance.changed?).to be false
    end
  end

  describe '#mark_dirty!' do
    it 'marks instance as changed' do
      instance.mark_dirty!
      expect(instance).to be_changed
    end
  end

  describe '#clear_dirty!' do
    it 'clears changed flag' do
      instance.mark_dirty!
      instance.clear_dirty!
      expect(instance).not_to be_changed
    end
  end

  describe '#changes' do
    context 'with no changes' do
      it 'returns empty array' do
        instance.original_attributes = { a: 1, b: 2 }
        instance.current_attributes = { a: 1, b: 2 }
        expect(instance.changes).to eq([])
      end
    end

    context 'with simple value changes' do
      it 'detects replaced values' do
        instance.original_attributes = { status: 'processing' }
        instance.current_attributes = { status: 'ready' }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :replace,
          path: [:status],
          old_value: 'processing',
          new_value: 'ready'
        )
      end

      it 'detects multiple changes' do
        instance.original_attributes = { a: 1, b: 2, c: 3 }
        instance.current_attributes = { a: 10, b: 2, c: 30 }

        changes = instance.changes
        expect(changes.size).to eq(2)

        paths = changes.map { |c| c[:path] }
        expect(paths).to contain_exactly([:a], [:c])
      end
    end

    context 'with added keys' do
      it 'detects added keys' do
        instance.original_attributes = { a: 1 }
        instance.current_attributes = { a: 1, b: 2 }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :add,
          path: [:b],
          value: 2
        )
      end

      it 'detects multiple added keys' do
        instance.original_attributes = { a: 1 }
        instance.current_attributes = { a: 1, b: 2, c: 3 }

        changes = instance.changes
        expect(changes.size).to eq(2)

        paths = changes.map { |c| c[:path] }
        expect(paths).to contain_exactly([:b], [:c])
      end
    end

    context 'with removed keys' do
      it 'detects removed keys' do
        instance.original_attributes = { a: 1, b: 2 }
        instance.current_attributes = { a: 1 }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :remove,
          path: [:b]
        )
      end
    end

    context 'with nested hash changes' do
      it 'detects changes in nested hashes' do
        instance.original_attributes = {
          metadata: {
            labels: { status: 'processing' }
          }
        }
        instance.current_attributes = {
          metadata: {
            labels: { status: 'ready' }
          }
        }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :replace,
          path: %i[metadata labels status],
          old_value: 'processing',
          new_value: 'ready'
        )
      end

      it 'detects added keys in nested hashes' do
        instance.original_attributes = {
          metadata: {
            labels: {}
          }
        }
        instance.current_attributes = {
          metadata: {
            labels: { new_key: 'value' }
          }
        }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :add,
          path: %i[metadata labels new_key],
          value: 'value'
        )
      end

      it 'detects removed keys in nested hashes' do
        instance.original_attributes = {
          metadata: {
            labels: { old_key: 'value', keep_key: 'value' }
          }
        }
        instance.current_attributes = {
          metadata: {
            labels: { keep_key: 'value' }
          }
        }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :remove,
          path: %i[metadata labels old_key]
        )
      end

      it 'detects deeply nested changes' do
        instance.original_attributes = {
          level1: {
            level2: {
              level3: 'old_value'
            }
          }
        }
        instance.current_attributes = {
          level1: {
            level2: {
              level3: 'new_value'
            }
          }
        }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :replace,
          path: %i[level1 level2 level3],
          old_value: 'old_value',
          new_value: 'new_value'
        )
      end
    end

    context 'with mixed changes' do
      it 'detects all change types together' do
        instance.original_attributes = {
          keep: 'same',
          replace: 'old',
          remove: 'value',
          nested: { inner: 'old' }
        }
        instance.current_attributes = {
          keep: 'same',
          replace: 'new',
          add: 'new_value',
          nested: { inner: 'new' }
        }

        changes = instance.changes
        # 4 changes: replace, remove, add, and nested change
        expect(changes.size).to eq(4)

        types = changes.map { |c| [c[:type], c[:path]] }
        expect(types).to contain_exactly(
          [:replace, [:replace]],
          [:remove, [:remove]],
          [:add, [:add]],
          [:replace, %i[nested inner]] # nested change
        )
      end
    end

    context 'with TrackedHash' do
      it 'handles TrackedHash in original_attributes' do
        tracked = PugClient::TrackedHash.new({ status: 'processing' })
        instance.original_attributes = { metadata: tracked }
        instance.current_attributes = { metadata: { status: 'ready' } }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first[:path]).to eq(%i[metadata status])
      end

      it 'handles TrackedHash in current_attributes' do
        tracked = PugClient::TrackedHash.new({ status: 'ready' })
        instance.original_attributes = { metadata: { status: 'processing' } }
        instance.current_attributes = { metadata: tracked }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first[:path]).to eq(%i[metadata status])
      end

      it 'handles TrackedHash in both attributes' do
        tracked_original = PugClient::TrackedHash.new({ status: 'processing' })
        tracked_current = PugClient::TrackedHash.new({ status: 'ready' })

        instance.original_attributes = { metadata: tracked_original }
        instance.current_attributes = { metadata: tracked_current }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first[:path]).to eq(%i[metadata status])
      end

      it 'considers equal TrackedHash as unchanged' do
        tracked1 = PugClient::TrackedHash.new({ a: 1, b: 2 })
        tracked2 = PugClient::TrackedHash.new({ a: 1, b: 2 })

        instance.original_attributes = { metadata: tracked1 }
        instance.current_attributes = { metadata: tracked2 }

        expect(instance.changes).to eq([])
      end
    end

    context 'with array changes' do
      it 'detects array replacement' do
        instance.original_attributes = { tags: %w[a b] }
        instance.current_attributes = { tags: %w[a b c] }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :replace,
          path: [:tags],
          old_value: %w[a b],
          new_value: %w[a b c]
        )
      end
    end

    context 'edge cases' do
      it 'returns empty array when attributes are nil' do
        instance.original_attributes = nil
        instance.current_attributes = nil
        expect(instance.changes).to eq([])
      end

      it 'handles empty hashes' do
        instance.original_attributes = {}
        instance.current_attributes = {}
        expect(instance.changes).to eq([])
      end

      it 'handles nil values' do
        instance.original_attributes = { a: nil }
        instance.current_attributes = { a: 'value' }

        changes = instance.changes
        expect(changes.size).to eq(1)
        expect(changes.first).to include(
          type: :replace,
          old_value: nil,
          new_value: 'value'
        )
      end
    end
  end
end
