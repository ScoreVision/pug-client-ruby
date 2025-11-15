# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient do
  describe 'Error classes' do
    it 'defines base Error class' do
      expect(PugClient::Error).to be < StandardError
    end

    it 'defines AuthenticationError' do
      expect(PugClient::AuthenticationError).to be < PugClient::Error
    end

    it 'defines ValidationError' do
      expect(PugClient::ValidationError).to be < PugClient::Error
    end

    it 'defines NetworkError' do
      expect(PugClient::NetworkError).to be < PugClient::Error
    end

    it 'defines TimeoutError' do
      expect(PugClient::TimeoutError).to be < PugClient::Error
    end

    it 'defines FeatureNotSupportedError' do
      expect(PugClient::FeatureNotSupportedError).to be < PugClient::Error
    end
  end

  describe PugClient::ResourceNotFound do
    it 'inherits from PugClient::Error' do
      expect(described_class).to be < PugClient::Error
    end

    it 'stores resource_type and id' do
      error = described_class.new('Video', 'video-123')
      expect(error.resource_type).to eq('Video')
      expect(error.id).to eq('video-123')
    end

    it 'generates helpful error message' do
      error = described_class.new('Video', 'video-123')
      expect(error.message).to eq('Video not found: video-123')
    end
  end

  describe PugClient::FeatureNotSupportedError do
    it 'inherits from PugClient::Error' do
      expect(described_class).to be < PugClient::Error
    end

    it 'generates message with feature name only' do
      error = described_class.new('Some feature')
      expect(error.message).to eq('Some feature is not supported by this client')
    end

    it 'generates message with feature name and reason' do
      error = described_class.new('Some feature', 'security concerns')
      expect(error.message).to eq('Some feature is not supported by this client: security concerns')
    end

    it 'handles nil reason gracefully' do
      error = described_class.new('Some feature', nil)
      expect(error.message).to eq('Some feature is not supported by this client')
    end
  end
end
