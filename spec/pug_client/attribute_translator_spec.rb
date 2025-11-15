# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PugClient::AttributeTranslator do
  describe '.underscore' do
    it 'converts camelCase to snake_case' do
      expect(described_class.underscore('startedAt')).to eq('started_at')
      expect(described_class.underscore('endedAt')).to eq('ended_at')
      expect(described_class.underscore('createdAt')).to eq('created_at')
    end

    it 'handles standard camelCase' do
      # Per OpenAPI spec, API uses standard camelCase
      expect(described_class.underscore('playbackUrls')).to eq('playback_urls')
      expect(described_class.underscore('streamUrls')).to eq('stream_urls')
      expect(described_class.underscore('thumbnailUrl')).to eq('thumbnail_url')
    end

    it 'handles already snake_case strings' do
      expect(described_class.underscore('already_snake')).to eq('already_snake')
      expect(described_class.underscore('snake_case_value')).to eq('snake_case_value')
    end

    it 'handles single words' do
      expect(described_class.underscore('video')).to eq('video')
      expect(described_class.underscore('namespace')).to eq('namespace')
    end

    it 'handles symbols' do
      expect(described_class.underscore(:startedAt)).to eq('started_at')
      expect(described_class.underscore(:playbackUrls)).to eq('playback_urls')
    end
  end

  describe '.camelize' do
    it 'converts snake_case to camelCase' do
      expect(described_class.camelize('started_at')).to eq('startedAt')
      expect(described_class.camelize('ended_at')).to eq('endedAt')
      expect(described_class.camelize('created_at')).to eq('createdAt')
    end

    it 'handles standard camelCase per actual API conventions' do
      # Per OpenAPI spec, API uses standard camelCase (not special acronym handling)
      expect(described_class.camelize('playback_urls')).to eq('playbackUrls')
      expect(described_class.camelize('stream_urls')).to eq('streamUrls')
      expect(described_class.camelize('thumbnail_url')).to eq('thumbnailUrl')
      expect(described_class.camelize('page_url')).to eq('pageUrl')
      expect(described_class.camelize('game_id')).to eq('gameId')
    end

    it 'handles already camelCase strings' do
      expect(described_class.camelize('alreadyCamel')).to eq('alreadyCamel')
      expect(described_class.camelize('camelCaseValue')).to eq('camelCaseValue')
    end

    it 'handles single words' do
      expect(described_class.camelize('video')).to eq('video')
      expect(described_class.camelize('namespace')).to eq('namespace')
    end

    it 'handles symbols' do
      expect(described_class.camelize(:started_at)).to eq('startedAt')
      expect(described_class.camelize(:playback_urls)).to eq('playbackUrls')
    end
  end

  describe '.from_api' do
    it 'converts simple hash from camelCase to snake_case' do
      input = { 'startedAt' => '2025-01-01', 'endedAt' => '2025-01-02' }
      output = described_class.from_api(input)

      expect(output).to eq({ started_at: '2025-01-01', ended_at: '2025-01-02' })
    end

    it 'converts nested hashes' do
      input = {
        'metadata' => {
          'labels' => { 'gameId' => '123' },
          'createdAt' => '2025-01-01'
        }
      }
      output = described_class.from_api(input)

      expect(output).to eq({
                             metadata: {
                               labels: { game_id: '123' },
                               created_at: '2025-01-01'
                             }
                           })
    end

    it 'converts arrays of hashes' do
      input = {
        'renditions' => [
          { 'videoURL' => 'http://example.com/1', 'bitRate' => 1000 },
          { 'videoURL' => 'http://example.com/2', 'bitRate' => 2000 }
        ]
      }
      output = described_class.from_api(input)

      expect(output).to eq({
                             renditions: [
                               { video_url: 'http://example.com/1', bit_rate: 1000 },
                               { video_url: 'http://example.com/2', bit_rate: 2000 }
                             ]
                           })
    end

    it 'handles mixed nesting (arrays and hashes)' do
      input = {
        'videos' => [
          {
            'id' => '1',
            'metadata' => {
              'labels' => { 'sportType' => 'basketball' }
            }
          }
        ]
      }
      output = described_class.from_api(input)

      expect(output).to eq({
                             videos: [
                               {
                                 id: '1',
                                 metadata: {
                                   labels: { sport_type: 'basketball' }
                                 }
                               }
                             ]
                           })
    end

    it 'preserves non-hash values' do
      input = {
        'string' => 'value',
        'number' => 123,
        'boolean' => true,
        'null' => nil
      }
      output = described_class.from_api(input)

      expect(output).to eq({
                             string: 'value',
                             number: 123,
                             boolean: true,
                             null: nil
                           })
    end

    it 'handles empty structures' do
      expect(described_class.from_api({})).to eq({})
      expect(described_class.from_api([])).to eq([])
      expect(described_class.from_api({ 'empty' => {} })).to eq({ empty: {} })
      expect(described_class.from_api({ 'empty' => [] })).to eq({ empty: [] })
    end

    it 'returns non-hash/non-array values unchanged' do
      expect(described_class.from_api('string')).to eq('string')
      expect(described_class.from_api(123)).to eq(123)
      expect(described_class.from_api(true)).to eq(true)
      expect(described_class.from_api(nil)).to eq(nil)
    end
  end

  describe '.to_api' do
    it 'converts simple hash from snake_case to camelCase' do
      input = { started_at: '2025-01-01', ended_at: '2025-01-02' }
      output = described_class.to_api(input)

      expect(output).to eq({ startedAt: '2025-01-01', endedAt: '2025-01-02' })
    end

    it 'converts nested hashes' do
      input = {
        metadata: {
          labels: { game_id: '123' },
          created_at: '2025-01-01'
        }
      }
      output = described_class.to_api(input)

      expect(output).to eq({
                             metadata: {
                               labels: { gameId: '123' },
                               createdAt: '2025-01-01'
                             }
                           })
    end

    it 'converts arrays of hashes with acronym handling' do
      input = {
        renditions: [
          { video_url: 'http://example.com/1', bit_rate: 1000 },
          { video_url: 'http://example.com/2', bit_rate: 2000 }
        ]
      }
      output = described_class.to_api(input)

      # NOTE: singular 'url' becomes 'Url' not 'URL' per API conventions
      expect(output).to eq({
                             renditions: [
                               { videoUrl: 'http://example.com/1', bitRate: 1000 },
                               { videoUrl: 'http://example.com/2', bitRate: 2000 }
                             ]
                           })
    end

    it 'handles mixed nesting (arrays and hashes)' do
      input = {
        videos: [
          {
            id: '1',
            metadata: {
              labels: { sport_type: 'basketball' }
            }
          }
        ]
      }
      output = described_class.to_api(input)

      expect(output).to eq({
                             videos: [
                               {
                                 id: '1',
                                 metadata: {
                                   labels: { sportType: 'basketball' }
                                 }
                               }
                             ]
                           })
    end

    it 'preserves non-hash values' do
      input = {
        string: 'value',
        number: 123,
        boolean: true,
        null: nil
      }
      output = described_class.to_api(input)

      expect(output).to eq({
                             string: 'value',
                             number: 123,
                             boolean: true,
                             null: nil
                           })
    end

    it 'handles empty structures' do
      expect(described_class.to_api({})).to eq({})
      expect(described_class.to_api([])).to eq([])
      expect(described_class.to_api({ empty: {} })).to eq({ empty: {} })
      expect(described_class.to_api({ empty: [] })).to eq({ empty: [] })
    end
  end

  describe 'round-trip conversion' do
    it 'converts from API to Ruby and back' do
      api_format = {
        'startedAt' => '2025-01-01',
        'metadata' => {
          'labels' => { 'gameId' => '123' }
        },
        'playbackUrls' => %w[url1 url2]
      }

      ruby_format = described_class.from_api(api_format)
      back_to_api = described_class.to_api(ruby_format)

      # Keys should match exactly (API uses standard camelCase)
      expect(back_to_api[:startedAt]).to eq('2025-01-01')
      expect(back_to_api[:metadata][:labels][:gameId]).to eq('123')
      expect(back_to_api[:playbackUrls]).to eq(%w[url1 url2])
    end
  end
end
