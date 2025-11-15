# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::Authentication do
  let(:client) do
    PugClient::Client.new(
      environment: :staging,
      namespace: 'test-namespace',
      client_id: 'test_client_id',
      client_secret: 'test_client_secret'
    )
  end

  describe '#authenticate!', :vcr do
    context 'with valid credentials' do
      before do
        stub_request(:post, 'https://fantagio-staging.auth0.com/oauth/token')
          .with(
            body: hash_including(
              client_id: 'test_client_id',
              client_secret: 'test_client_secret',
              audience: 'https://staging-api.fantag.io/',
              grant_type: 'client_credentials'
            )
          )
          .to_return(
            status: 200,
            body: {
              access_token: 'test_access_token_12345',
              token_type: 'Bearer',
              expires_in: 86_400
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches and stores an access token' do
        result = client.authenticate!
        expect(result).to eq(true)
        expect(client.instance_variable_get(:@access_token)).to eq('test_access_token_12345')
      end

      it 'calculates and stores token expiration time' do
        freeze_time = Time.new(2025, 1, 1, 12, 0, 0)
        allow(Time).to receive(:now).and_return(freeze_time)

        client.authenticate!

        expected_expiry = freeze_time + 86_400
        expect(client.instance_variable_get(:@token_expires_at)).to eq(expected_expiry)
      end
    end

    context 'with invalid credentials' do
      before do
        stub_request(:post, 'https://fantagio-staging.auth0.com/oauth/token')
          .to_return(
            status: 401,
            body: { error: 'invalid_client' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises an AuthenticationError' do
        expect { client.authenticate! }.to raise_error(
          PugClient::AuthenticationError,
          /Authentication failed: 401/
        )
      end
    end

    context 'when auth endpoint is unreachable' do
      before do
        stub_request(:post, 'https://fantagio-staging.auth0.com/oauth/token')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an AuthenticationError' do
        expect { client.authenticate! }.to raise_error(
          PugClient::AuthenticationError,
          /Authentication failed: 500/
        )
      end
    end
  end

  describe '#authenticated?' do
    context 'when access token is set' do
      before do
        client.instance_variable_set(:@access_token, 'test_token')
      end

      it 'returns true' do
        expect(client.authenticated?).to eq(true)
      end
    end

    context 'when access token is not set' do
      it 'returns false' do
        expect(client.authenticated?).to eq(false)
      end
    end

    context 'when access token is nil' do
      before do
        client.instance_variable_set(:@access_token, nil)
      end

      it 'returns false' do
        expect(client.authenticated?).to eq(false)
      end
    end
  end

  describe '#token_expired?' do
    context 'when token_expires_at is not set' do
      it 'returns true' do
        expect(client.token_expired?).to eq(true)
      end
    end

    context 'when token has expired' do
      before do
        past_time = Time.now - 3600
        client.instance_variable_set(:@token_expires_at, past_time)
      end

      it 'returns true' do
        expect(client.token_expired?).to eq(true)
      end
    end

    context 'when token has not expired' do
      before do
        future_time = Time.now + 3600
        client.instance_variable_set(:@token_expires_at, future_time)
      end

      it 'returns false' do
        expect(client.token_expired?).to eq(false)
      end
    end

    context 'when token is exactly at expiration time' do
      before do
        now = Time.now
        allow(Time).to receive(:now).and_return(now)
        client.instance_variable_set(:@token_expires_at, now)
      end

      it 'returns true' do
        expect(client.token_expired?).to eq(true)
      end
    end
  end

  describe '#ensure_authenticated!' do
    context 'when not authenticated' do
      it 'calls authenticate!' do
        expect(client).to receive(:authenticate!)
        client.ensure_authenticated!
      end
    end

    context 'when authenticated but token is expired' do
      before do
        client.instance_variable_set(:@access_token, 'old_token')
        past_time = Time.now - 3600
        client.instance_variable_set(:@token_expires_at, past_time)
      end

      it 'calls authenticate! to refresh the token' do
        expect(client).to receive(:authenticate!)
        client.ensure_authenticated!
      end
    end

    context 'when authenticated and token is not expired' do
      before do
        client.instance_variable_set(:@access_token, 'valid_token')
        future_time = Time.now + 3600
        client.instance_variable_set(:@token_expires_at, future_time)
      end

      it 'does not call authenticate!' do
        expect(client).not_to receive(:authenticate!)
        client.ensure_authenticated!
      end
    end
  end
end
