# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Connection do
  let(:client) do
    PugClient::Client.new(
      environment: :staging,
      namespace: 'test-namespace',
      client_id: 'test_id',
      client_secret: 'test_secret'
    ).tap do |c|
      c.instance_variable_set(:@access_token, 'test_access_token')
      c.instance_variable_set(:@token_expires_at, Time.now + 3600) # Token valid for 1 hour
    end
  end

  describe 'HTTP methods' do
    describe '#get' do
      it 'makes a GET request' do
        stub_request(:get, 'https://staging-api.video.scorevision.com/test')
          .to_return(
            status: 200,
            body: { data: { id: '123', type: 'test' } }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }
          )

        response = client.get('test')
        expect(response).to be_a(Hash)
      end

      it 'includes authorization header' do
        stub = stub_request(:get, 'https://staging-api.video.scorevision.com/test')
               .with(headers: { 'Authorization' => 'Bearer test_access_token' })
               .to_return(
                 status: 200,
                 body: { data: {} }.to_json,
                 headers: { 'Content-Type' => 'application/vnd.api+json' }
               )

        client.get('test')
        expect(stub).to have_been_requested
      end

      it 'includes JSON:API content type header' do
        stub = stub_request(:get, 'https://staging-api.video.scorevision.com/test')
               .with(headers: { 'Accept' => 'application/vnd.api+json' })
               .to_return(
                 status: 200,
                 body: { data: {} }.to_json,
                 headers: { 'Content-Type' => 'application/vnd.api+json' }
               )

        client.get('test')
        expect(stub).to have_been_requested
      end
    end

    describe '#post' do
      it 'makes a POST request' do
        stub_request(:post, 'https://staging-api.video.scorevision.com/test')
          .with(body: { data: { type: 'test', id: '123' } })
          .to_return(
            status: 201,
            body: { data: { id: '123', type: 'test' } }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }
          )

        response = client.post('test', data: { type: 'test', id: '123' })
        expect(response).to be_a(Hash)
      end

      it 'includes authorization header' do
        stub = stub_request(:post, 'https://staging-api.video.scorevision.com/test')
               .with(headers: { 'Authorization' => 'Bearer test_access_token' })
               .to_return(
                 status: 201,
                 body: { data: {} }.to_json,
                 headers: { 'Content-Type' => 'application/vnd.api+json' }
               )

        client.post('test', data: {})
        expect(stub).to have_been_requested
      end
    end

    describe '#patch' do
      it 'makes a PATCH request' do
        stub_request(:patch, 'https://staging-api.video.scorevision.com/test/123')
          .to_return(
            status: 200,
            body: { data: { id: '123', type: 'test' } }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }
          )

        response = client.patch('test/123', [{ op: 'replace', path: '/name', value: 'new' }])
        expect(response).to be_a(Hash)
      end
    end

    describe '#delete' do
      it 'makes a DELETE request' do
        stub_request(:delete, 'https://staging-api.video.scorevision.com/test/123')
          .to_return(
            status: 204,
            body: '',
            headers: {}
          )

        client.delete('test/123')
        expect(a_request(:delete, 'https://staging-api.video.scorevision.com/test/123')).to have_been_made
      end
    end

    describe '#put' do
      it 'makes a PUT request' do
        stub_request(:put, 'https://staging-api.video.scorevision.com/test/123')
          .to_return(
            status: 200,
            body: { data: {} }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }
          )

        response = client.put('test/123', data: {})
        expect(response).to be_a(Hash)
      end
    end
  end

  describe '#paginate' do
    context 'without auto_paginate' do
      before do
        client.instance_variable_set(:@auto_paginate, false)
        client.instance_variable_set(:@per_page, 10)
      end

      it 'returns a single page of results' do
        stub_request(:get, 'https://staging-api.video.scorevision.com/items')
          .with(query: { 'page[size]' => '10' })
          .to_return(
            status: 200,
            body: {
              data: [{ id: '1', type: 'item' }, { id: '2', type: 'item' }],
              links: { next: 'https://staging-api.video.scorevision.com/items?page[after]=cursor123' }
            }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }
          )

        response = client.paginate('items')
        expect(response).to be_an(Array)
      end

      it 'uses custom page size when provided' do
        stub = stub_request(:get, 'https://staging-api.video.scorevision.com/items')
               .with(query: { 'page[size]' => '25' })
               .to_return(
                 status: 200,
                 body: { data: [] }.to_json,
                 headers: { 'Content-Type' => 'application/vnd.api+json' }
               )

        client.paginate('items', query: { page: { size: 25 } })
        expect(stub).to have_been_requested
      end
    end

    # NOTE: auto_paginate tests removed - ResourceEnumerator handles pagination differently
  end

  describe '#last_response' do
    it 'stores the last HTTP response' do
      stub_request(:get, 'https://staging-api.video.scorevision.com/test')
        .to_return(
          status: 200,
          body: { data: {} }.to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' }
        )

      client.get('test')
      expect(client.last_response).to be_a(PugClient::Connection::Response)
      expect(client.last_response.status).to eq(200)
    end
  end

  describe 'request options' do
    it 'supports custom query parameters' do
      stub = stub_request(:get, 'https://staging-api.video.scorevision.com/items')
             .with(query: { 'filter' => 'active', 'sort' => 'created_at' })
             .to_return(
               status: 200,
               body: { data: [] }.to_json,
               headers: { 'Content-Type' => 'application/vnd.api+json' }
             )

      client.get('items', query: { filter: 'active', sort: 'created_at' })
      expect(stub).to have_been_requested
    end

    it 'supports custom headers' do
      stub = stub_request(:get, 'https://staging-api.video.scorevision.com/items')
             .with(headers: { 'X-Custom-Header' => 'custom-value' })
             .to_return(
               status: 200,
               body: { data: [] }.to_json,
               headers: { 'Content-Type' => 'application/vnd.api+json' }
             )

      client.get('items', headers: { 'X-Custom-Header' => 'custom-value' })
      expect(stub).to have_been_requested
    end
  end
end
