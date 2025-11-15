# frozen_string_literal: true

require 'spec_helper'

# NamespaceClients are intentionally not supported by this Ruby client.
# The API endpoint exists but is excluded for security and architectural reasons.
RSpec.describe 'NamespaceClients Integration', :integration do
  let(:client) do
    PugClient::Client.new(
      namespace: 'test-namespace',
      client_id: 'test-id',
      client_secret: 'test-secret'
    )
  end

  describe 'creating a namespace client' do
    it 'raises FeatureNotSupportedError' do
      expect do
        client.create_namespace_client
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /Namespace client creation is not supported/
      )
    end

    it 'provides helpful error message' do
      expect do
        client.create_namespace_client
      end.to raise_error(
        PugClient::FeatureNotSupportedError,
        /intentionally excluded.*web console/
      )
    end
  end
end
