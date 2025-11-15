# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'PugClient::Default' do
  describe PugClient::DefaultProduction do
    describe '.options' do
      it 'returns a hash of all configuration options' do
        options = PugClient::DefaultProduction.options
        expect(options).to be_a(Hash)
        expect(options.keys).to match_array(PugClient::Configurable.keys)
      end
    end

    describe '.api_endpoint' do
      it 'returns the production API endpoint' do
        expect(PugClient::DefaultProduction.api_endpoint).to eq('https://api.video.scorevision.com')
      end
    end

    describe '.auth_endpoint' do
      it 'returns the production Auth0 token endpoint' do
        expect(PugClient::DefaultProduction.auth_endpoint).to eq('https://fantagio.auth0.com/oauth/token')
      end
    end

    describe '.auth_audience' do
      it 'returns the production API audience' do
        expect(PugClient::DefaultProduction.auth_audience).to eq('https://api.fantag.io/')
      end
    end

    describe '.auth_grant_type' do
      it 'returns client_credentials grant type' do
        expect(PugClient::DefaultProduction.auth_grant_type).to eq('client_credentials')
      end
    end

    describe '.client_id' do
      it 'reads from PUG_CLIENT_ID environment variable' do
        allow(ENV).to receive(:[]).with('PUG_CLIENT_ID').and_return('test_id')
        expect(PugClient::DefaultProduction.client_id).to eq('test_id')
      end
    end

    describe '.client_secret' do
      it 'reads from PUG_CLIENT_SECRET environment variable' do
        allow(ENV).to receive(:[]).with('PUG_CLIENT_SECRET').and_return('test_secret')
        expect(PugClient::DefaultProduction.client_secret).to eq('test_secret')
      end
    end

    describe '.per_page' do
      it 'returns default per_page value of 10' do
        expect(PugClient::DefaultProduction.per_page).to eq(10)
      end
    end

    describe '.auto_paginate' do
      it 'returns false by default' do
        expect(PugClient::DefaultProduction.auto_paginate).to eq(false)
      end
    end

    describe '.connection_options' do
      it 'returns connection options with timeouts' do
        options = PugClient::DefaultProduction.connection_options
        expect(options[:request][:open_timeout]).to eq(5)
        expect(options[:request][:timeout]).to eq(10)
      end
    end
  end

  describe PugClient::DefaultStaging do
    describe '.options' do
      it 'returns a hash of all configuration options' do
        options = PugClient::DefaultStaging.options
        expect(options).to be_a(Hash)
        expect(options.keys).to match_array(PugClient::Configurable.keys)
      end
    end

    describe '.api_endpoint' do
      it 'returns the staging API endpoint' do
        expect(PugClient::DefaultStaging.api_endpoint).to eq('https://staging-api.video.scorevision.com')
      end
    end

    describe '.auth_endpoint' do
      it 'returns the staging Auth0 token endpoint' do
        expect(PugClient::DefaultStaging.auth_endpoint).to eq('https://fantagio-staging.auth0.com/oauth/token')
      end
    end

    describe '.auth_audience' do
      it 'returns the staging API audience' do
        expect(PugClient::DefaultStaging.auth_audience).to eq('https://staging-api.fantag.io/')
      end
    end

    describe '.auth_grant_type' do
      it 'returns client_credentials grant type' do
        expect(PugClient::DefaultStaging.auth_grant_type).to eq('client_credentials')
      end
    end

    describe '.client_id' do
      it 'reads from PUG_CLIENT_ID environment variable' do
        allow(ENV).to receive(:[]).with('PUG_CLIENT_ID').and_return('staging_id')
        expect(PugClient::DefaultStaging.client_id).to eq('staging_id')
      end
    end

    describe '.client_secret' do
      it 'reads from PUG_CLIENT_SECRET environment variable' do
        allow(ENV).to receive(:[]).with('PUG_CLIENT_SECRET').and_return('staging_secret')
        expect(PugClient::DefaultStaging.client_secret).to eq('staging_secret')
      end
    end

    describe '.per_page' do
      it 'returns default per_page value of 10' do
        expect(PugClient::DefaultStaging.per_page).to eq(10)
      end
    end

    describe '.auto_paginate' do
      it 'returns false by default' do
        expect(PugClient::DefaultStaging.auto_paginate).to eq(false)
      end
    end

    describe '.connection_options' do
      it 'returns connection options with timeouts' do
        options = PugClient::DefaultStaging.connection_options
        expect(options[:request][:open_timeout]).to eq(5)
        expect(options[:request][:timeout]).to eq(10)
      end
    end
  end
end
