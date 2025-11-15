# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::ResourceEnumerator do
  # Mock resource class
  let(:mock_resource_class) do
    Class.new do
      attr_reader :id

      def self.from_api_data(_client, data, _options = {})
        new(data[:id] || data['id'])
      end

      def initialize(id)
        @id = id
      end
    end
  end

  # Mock client
  let(:client) do
    double('Client', per_page: 10)
  end

  describe '#each' do
    it 'yields each resource from single page' do
      # Mock single page response
      response = [
        { 'id' => '1' },
        { 'id' => '2' },
        { 'id' => '3' }
      ]

      allow(client).to receive(:get).and_return(response)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = []
      enumerator.each { |resource| ids << resource.id }

      expect(ids).to eq(%w[1 2 3])
    end

    it 'follows pagination links' do
      # Mock first page - plain hash with data and links
      page1 = {
        data: [{ 'id' => '1' }, { 'id' => '2' }],
        links: { next: 'namespaces/test/videos?page[after]=cursor1' }
      }

      # Mock second page (final) - plain array
      page2 = [{ 'id' => '3' }, { 'id' => '4' }]

      allow(client).to receive(:get)
        .with('namespaces/test/videos', hash_including(query: hash_including(page: { size: 10 })))
        .and_return(page1)

      allow(client).to receive(:get)
        .with('namespaces/test/videos?page[after]=cursor1', {})
        .and_return(page2)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = []
      enumerator.each { |resource| ids << resource.id }

      expect(ids).to eq(%w[1 2 3 4])
    end

    it 'returns enumerator when no block given' do
      allow(client).to receive(:get).and_return([{ 'id' => '1' }])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      result = enumerator.each
      expect(result).to be_a(Enumerator)
    end

    it 'stops on empty page' do
      # Empty response
      allow(client).to receive(:get).and_return([])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = []
      enumerator.each { |resource| ids << resource.id }

      expect(ids).to be_empty
    end

    it 'uses client per_page setting' do
      client_with_custom_size = double('Client', per_page: 25)

      allow(client_with_custom_size).to receive(:get) do |_url, params|
        expect(params.dig(:query, :page, :size)).to eq(25)
        []
      end

      enumerator = described_class.new(
        client: client_with_custom_size,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      enumerator.to_a
    end

    it 'uses custom query options' do
      allow(client).to receive(:get) do |_url, params|
        expect(params[:query]).to include(filter: { label: 'test' })
        expect(params[:query]).to include(page: { size: 10 })
        []
      end

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos',
        options: { query: { filter: { label: 'test' } } }
      )

      enumerator.to_a
    end
  end

  describe '#first' do
    it 'returns first item when called without argument' do
      allow(client).to receive(:get).and_return([{ 'id' => '1' }, { 'id' => '2' }])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      first = enumerator.first
      expect(first.id).to eq('1')
    end

    it 'returns first N items' do
      allow(client).to receive(:get).and_return([
                                                  { 'id' => '1' },
                                                  { 'id' => '2' },
                                                  { 'id' => '3' },
                                                  { 'id' => '4' },
                                                  { 'id' => '5' }
                                                ])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      first_3 = enumerator.first(3)
      expect(first_3.map(&:id)).to eq(%w[1 2 3])
    end

    it 'stops fetching after N items' do
      # Should only call once since we get 5 items and only need 3
      expect(client).to receive(:get).once.and_return([
                                                        { 'id' => '1' },
                                                        { 'id' => '2' },
                                                        { 'id' => '3' },
                                                        { 'id' => '4' },
                                                        { 'id' => '5' }
                                                      ])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      enumerator.first(3)
    end
  end

  describe '#to_a' do
    it 'forces eager loading of all items' do
      page1 = {
        data: [{ 'id' => '1' }],
        links: { next: 'page2' }
      }

      page2 = [{ 'id' => '2' }]

      allow(client).to receive(:get)
        .with('namespaces/test/videos', anything)
        .and_return(page1)

      allow(client).to receive(:get)
        .with('page2', {})
        .and_return(page2)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      array = enumerator.to_a
      expect(array.size).to eq(2)
      expect(array.map(&:id)).to eq(%w[1 2])
    end
  end

  describe 'Enumerable methods' do
    before do
      allow(client).to receive(:get).and_return([
                                                  { 'id' => '1' },
                                                  { 'id' => '2' },
                                                  { 'id' => '3' }
                                                ])
    end

    let(:enumerator) do
      described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )
    end

    it 'supports map' do
      ids = enumerator.map(&:id)
      expect(ids).to eq(%w[1 2 3])
    end

    it 'supports select' do
      selected = enumerator.select { |r| r.id.to_i.odd? }
      expect(selected.map(&:id)).to eq(%w[1 3])
    end

    it 'supports count' do
      expect(enumerator.count).to eq(3)
    end

    it 'supports any?' do
      expect(enumerator.any? { |r| r.id == '2' }).to be true
      expect(enumerator.any? { |r| r.id == '999' }).to be false
    end
  end

  describe 'response format handling' do
    it 'handles array response' do
      response = [{ 'id' => '1' }, { 'id' => '2' }]
      allow(client).to receive(:get).and_return(response)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = enumerator.map(&:id)
      expect(ids).to eq(%w[1 2])
    end

    it 'handles wrapped response with data array' do
      response = {
        data: [{ 'id' => '1' }, { 'id' => '2' }],
        links: { next: nil }
      }

      allow(client).to receive(:get).and_return(response)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = enumerator.map(&:id)
      expect(ids).to eq(%w[1 2])
    end

    it 'handles single item wrapped in data' do
      response = {
        data: { 'id' => '1' },
        links: { next: nil }
      }

      allow(client).to receive(:get).and_return(response)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'namespaces/test/videos'
      )

      ids = enumerator.map(&:id)
      expect(ids).to eq(['1'])
    end
  end

  describe 'resource instantiation' do
    it 'passes options to resource class' do
      mock_class_with_options = Class.new do
        attr_reader :id, :namespace_id

        def self.from_api_data(_client, data, options = {})
          new(data[:id], options[:namespace_id])
        end

        def initialize(id, namespace_id)
          @id = id
          @namespace_id = namespace_id
        end
      end

      allow(client).to receive(:get).and_return([{ id: '1' }])

      enumerator = described_class.new(
        client: client,
        resource_class: mock_class_with_options,
        base_url: 'namespaces/test/videos',
        options: { _namespace_id: 'test' } # _prefix indicates instantiation option
      )

      resource = enumerator.first
      expect(resource.namespace_id).to eq('test')
    end
  end

  describe 'pagination link detection' do
    it 'uses JSON:API links.next' do
      page1 = {
        data: [{ 'id' => '1' }],
        links: { next: 'next_url' }
      }

      page2 = [{ 'id' => '2' }]

      allow(client).to receive(:get)
        .with('test', anything)
        .and_return(page1)

      allow(client).to receive(:get)
        .with('next_url', {})
        .and_return(page2)

      enumerator = described_class.new(
        client: client,
        resource_class: mock_resource_class,
        base_url: 'test'
      )

      ids = enumerator.map(&:id)
      expect(ids).to eq(%w[1 2])
    end
  end
end
