# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::TrackedHash do
  # Mock parent resource for tracking
  let(:parent) do
    double('Resource', mark_dirty!: true)
  end

  describe '#initialize' do
    it 'creates an empty hash when no arguments given' do
      hash = described_class.new
      expect(hash).to be_empty
    end

    it 'creates hash from initial hash' do
      hash = described_class.new({ a: 1, b: 2 })
      expect(hash[:a]).to eq(1)
      expect(hash[:b]).to eq(2)
    end

    it 'wraps nested hashes' do
      hash = described_class.new({ nested: { key: 'value' } }, parent_resource: parent)
      expect(hash[:nested]).to be_a(described_class)
    end

    it 'wraps hashes in arrays' do
      hash = described_class.new({ items: [{ id: 1 }, { id: 2 }] }, parent_resource: parent)
      expect(hash[:items][0]).to be_a(described_class)
      expect(hash[:items][1]).to be_a(described_class)
    end

    it 'stores parent resource reference' do
      hash = described_class.new({}, parent_resource: parent)
      expect(hash.parent_resource).to eq(parent)
    end
  end

  describe '#[]=' do
    it 'sets value' do
      hash = described_class.new
      hash[:key] = 'value'
      expect(hash[:key]).to eq('value')
    end

    it 'marks parent as dirty' do
      hash = described_class.new({}, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash[:key] = 'value'
    end

    it 'wraps nested hash values' do
      hash = described_class.new({}, parent_resource: parent)
      hash[:nested] = { key: 'value' }
      expect(hash[:nested]).to be_a(described_class)
    end

    it 'does not error without parent resource' do
      hash = described_class.new
      expect { hash[:key] = 'value' }.not_to raise_error
    end

    it 'propagates parent to nested hashes' do
      hash = described_class.new({}, parent_resource: parent)
      hash[:nested] = { key: 'value' }
      expect(hash[:nested].parent_resource).to eq(parent)
    end
  end

  describe '#delete' do
    it 'deletes key and returns value' do
      hash = described_class.new({ key: 'value' })
      expect(hash.delete(:key)).to eq('value')
      expect(hash[:key]).to be_nil
    end

    it 'marks parent as dirty' do
      hash = described_class.new({ key: 'value' }, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.delete(:key)
    end
  end

  describe '#merge!' do
    it 'merges other hash' do
      hash = described_class.new({ a: 1 })
      hash.merge!(b: 2, c: 3)
      expect(hash[:a]).to eq(1)
      expect(hash[:b]).to eq(2)
      expect(hash[:c]).to eq(3)
    end

    it 'marks parent as dirty' do
      hash = described_class.new({ a: 1 }, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.merge!(b: 2)
    end

    it 'returns self' do
      hash = described_class.new({ a: 1 })
      result = hash.merge!(b: 2)
      expect(result).to eq(hash)
    end

    it 'wraps nested hashes from merged data' do
      hash = described_class.new({}, parent_resource: parent)
      hash.merge!(nested: { key: 'value' })
      expect(hash[:nested]).to be_a(described_class)
    end
  end

  describe '#update' do
    it 'updates hash with other hash' do
      hash = described_class.new({ a: 1 })
      hash.update(a: 2, b: 3)
      expect(hash[:a]).to eq(2)
      expect(hash[:b]).to eq(3)
    end

    it 'marks parent as dirty' do
      hash = described_class.new({ a: 1 }, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.update(b: 2)
    end

    it 'returns self' do
      hash = described_class.new({ a: 1 })
      result = hash.update(b: 2)
      expect(result).to eq(hash)
    end
  end

  describe '#store' do
    it 'stores value' do
      hash = described_class.new
      hash.store(:key, 'value')
      expect(hash[:key]).to eq('value')
    end

    it 'marks parent as dirty' do
      hash = described_class.new({}, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.store(:key, 'value')
    end
  end

  describe '#clear' do
    it 'clears all contents' do
      hash = described_class.new({ a: 1, b: 2 })
      hash.clear
      expect(hash).to be_empty
    end

    it 'marks parent as dirty' do
      hash = described_class.new({ a: 1 }, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.clear
    end

    it 'returns self' do
      hash = described_class.new({ a: 1 })
      result = hash.clear
      expect(result).to eq(hash)
    end
  end

  describe '#replace' do
    it 'replaces contents with other hash' do
      hash = described_class.new({ a: 1, b: 2 })
      hash.replace(c: 3, d: 4)
      expect(hash[:a]).to be_nil
      expect(hash[:b]).to be_nil
      expect(hash[:c]).to eq(3)
      expect(hash[:d]).to eq(4)
    end

    it 'marks parent as dirty' do
      hash = described_class.new({ a: 1 }, parent_resource: parent)
      expect(parent).to receive(:mark_dirty!)
      hash.replace(b: 2)
    end

    it 'returns self' do
      hash = described_class.new({ a: 1 })
      result = hash.replace(b: 2)
      expect(result).to eq(hash)
    end
  end

  describe 'nested modifications' do
    it 'marks parent dirty when nested hash is modified' do
      hash = described_class.new({ nested: { key: 'value' } }, parent_resource: parent)

      # Modifying nested hash should mark parent dirty
      expect(parent).to receive(:mark_dirty!)
      hash[:nested][:new_key] = 'new_value'
    end

    it 'marks parent dirty when deeply nested hash is modified' do
      hash = described_class.new(
        { level1: { level2: { level3: 'value' } } },
        parent_resource: parent
      )

      # Modifying deeply nested hash should mark parent dirty
      expect(parent).to receive(:mark_dirty!)
      hash[:level1][:level2][:level3] = 'new_value'
    end

    it 'handles modifications to hashes in arrays' do
      hash = described_class.new({ items: [{ id: 1 }] }, parent_resource: parent)

      # Modifying hash inside array should mark parent dirty
      expect(parent).to receive(:mark_dirty!)
      hash[:items][0][:id] = 2
    end
  end

  describe 'non-mutating methods' do
    let(:hash) { described_class.new({ a: 1, b: 2 }, parent_resource: parent) }

    it 'does not mark parent dirty on read operations' do
      expect(parent).not_to receive(:mark_dirty!)
      hash[:a]
      hash.fetch(:b)
      hash.key?(:a)
      hash.keys
      hash.values
    end

    it 'does not mark parent dirty on iteration' do
      expect(parent).not_to receive(:mark_dirty!)
      hash.each { |k, v| }
      hash.map { |k, v| [k, v] }
      hash.select { |k, _v| k == :a }
    end
  end

  describe 'works like regular hash' do
    let(:hash) { described_class.new({ a: 1, b: 2, c: 3 }) }

    it 'supports key access' do
      expect(hash[:a]).to eq(1)
      expect(hash[:b]).to eq(2)
    end

    it 'supports keys method' do
      expect(hash.keys).to contain_exactly(:a, :b, :c)
    end

    it 'supports values method' do
      expect(hash.values).to contain_exactly(1, 2, 3)
    end

    it 'supports each' do
      result = {}
      hash.each { |k, v| result[k] = v }
      expect(result).to eq({ a: 1, b: 2, c: 3 })
    end

    it 'supports to_h' do
      expect(hash.to_h).to eq({ a: 1, b: 2, c: 3 })
    end
  end
end
