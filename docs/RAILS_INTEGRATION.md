# Rails Integration Guide

This guide shows how to integrate the Pug Video API client into Ruby on Rails applications.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Controller Examples](#controller-examples)
- [Background Job Examples](#background-job-examples)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Best Practices](#best-practices)

## Installation

Add to your Gemfile:

```ruby
gem 'pug-client'
```

Then run:

```bash
bundle install
```

## Configuration

### Environment Variables

Add to your `.env` file (using dotenv-rails or similar):

```bash
# Production credentials
PUG_CLIENT_ID=your_production_client_id
PUG_CLIENT_SECRET=your_production_client_secret
PUG_NAMESPACE=your_default_namespace

# Staging credentials (optional)
PUG_STAGING_CLIENT_ID=your_staging_client_id
PUG_STAGING_CLIENT_SECRET=your_staging_client_secret
PUG_STAGING_NAMESPACE=your_staging_namespace
```

### Initializer

Create `config/initializers/pug_client.rb`:

```ruby
# config/initializers/pug_client.rb

PugClient.configure do |config|
  # Set environment based on Rails environment
  config.environment = Rails.env.production? ? :production : :staging

  # Namespace (required) - defaults handled automatically from ENV
  config.namespace = ENV['PUG_NAMESPACE']

  # Credentials - defaults handled automatically from ENV
  # config.client_id = ENV['PUG_CLIENT_ID']
  # config.client_secret = ENV['PUG_CLIENT_SECRET']

  # Optional: Adjust pagination defaults
  config.per_page = 20

  # Optional: Customize connection timeouts
  config.connection_options = {
    request: {
      open_timeout: 10,
      timeout: 30
    }
  }
end
```

**Note:** The gem automatically reads `PUG_CLIENT_ID`, `PUG_CLIENT_SECRET`, and `PUG_NAMESPACE` from environment variables, so explicit configuration is optional.

### Per-User Namespaces

If different users have different namespaces, create clients per-request:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def pug_client
    @pug_client ||= PugClient::Client.new(
      namespace: current_user.pug_namespace,
      environment: Rails.env.production? ? :production : :staging
    ).tap(&:authenticate!)
  end
end
```

## Controller Examples

### Example 1: Video Upload Controller

Create a controller that handles video uploads from users:

```ruby
# app/controllers/videos_controller.rb
class VideosController < ApplicationController
  before_action :authenticate_user!

  # POST /videos
  def create
    # Create Pug client for user's namespace
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    # Create video resource with metadata
    video = client.create_video(
      Time.now.utc.iso8601,
      metadata: {
        labels: {
          title: params[:title],
          description: params[:description],
          uploaded_by: current_user.id.to_s,
          uploaded_at: Time.now.utc.iso8601,
          user_email: current_user.email
        }
      }
    )

    # Upload file if provided
    if params[:file].present?
      File.open(params[:file].path, 'rb') do |file|
        video.upload(file, filename: params[:file].original_filename)
      end

      # Queue background job to wait for processing
      VideoProcessingJob.perform_later(video.id, current_user.pug_namespace)
    end

    # Save video ID to database for tracking
    user_video = current_user.videos.create!(
      pug_video_id: video.id,
      title: params[:title],
      status: 'processing'
    )

    render json: {
      id: video.id,
      status: 'processing',
      database_id: user_video.id
    }, status: :created

  rescue PugClient::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue PugClient::AuthenticationError => e
    render json: { error: 'Authentication failed' }, status: :unauthorized
  rescue PugClient::NetworkError => e
    render json: { error: 'Service unavailable' }, status: :service_unavailable
  end

  # GET /videos
  def index
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    # Fetch videos with pagination
    per_page = params[:per_page]&.to_i || 20
    videos = client.videos.first(per_page)

    render json: videos.map { |video|
      {
        id: video.id,
        started_at: video.started_at,
        duration: video.duration,
        metadata: video.metadata,
        playback_urls: video.playback_urls,
        thumbnail_url: video.thumbnail_url
      }
    }
  end

  # GET /videos/:id
  def show
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    video = client.video(params[:id])

    render json: {
      id: video.id,
      started_at: video.started_at,
      duration: video.duration,
      status: video.renditions.present? ? 'ready' : 'processing',
      metadata: video.metadata,
      playback_urls: video.playback_urls,
      thumbnail_url: video.thumbnail_url,
      renditions: video.renditions
    }
  rescue PugClient::ResourceNotFound
    render json: { error: 'Video not found' }, status: :not_found
  end

  # PATCH /videos/:id
  def update
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    video = client.video(params[:id])

    # Update metadata labels
    params[:metadata][:labels].each do |key, value|
      video.metadata[:labels][key.to_sym] = value
    end if params[:metadata]

    video.save

    render json: {
      id: video.id,
      metadata: video.metadata
    }
  rescue PugClient::ResourceNotFound
    render json: { error: 'Video not found' }, status: :not_found
  rescue PugClient::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /videos/:id
  def destroy
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    video = client.video(params[:id])
    video.delete

    # Update local database record
    user_video = current_user.videos.find_by(pug_video_id: params[:id])
    user_video&.update(status: 'deleted')

    head :no_content
  rescue PugClient::ResourceNotFound
    render json: { error: 'Video not found' }, status: :not_found
  end
end
```

### Example 2: Video Clipping Controller

Create highlights/clips from existing videos:

```ruby
# app/controllers/clips_controller.rb
class ClipsController < ApplicationController
  before_action :authenticate_user!

  # POST /videos/:video_id/clips
  def create
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    # Get source video
    source_video = client.video(params[:video_id])

    # Create clip
    clip = source_video.clip(
      start_time: params[:start_time].to_i,  # milliseconds
      duration: params[:duration].to_i,      # milliseconds
      metadata: {
        labels: {
          title: params[:title],
          clip_type: params[:clip_type] || 'highlight',
          created_by: current_user.id.to_s,
          source_video_id: source_video.id
        }
      }
    )

    # Save to database
    user_clip = current_user.clips.create!(
      pug_clip_id: clip.id,
      pug_source_video_id: source_video.id,
      title: params[:title],
      start_time: params[:start_time],
      duration: params[:duration],
      status: 'processing'
    )

    # Queue processing job
    ClipProcessingJob.perform_later(clip.id, current_user.pug_namespace)

    render json: {
      id: clip.id,
      status: 'processing',
      database_id: user_clip.id
    }, status: :created
  rescue PugClient::ResourceNotFound
    render json: { error: 'Source video not found' }, status: :not_found
  end
end
```

### Example 3: LiveStream Controller

Manage livestreams:

```ruby
# app/controllers/livestreams_controller.rb
class LivestreamsController < ApplicationController
  before_action :authenticate_user!

  # POST /livestreams
  def create
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    livestream = client.create_livestream(
      params[:title],
      metadata: {
        labels: {
          event: params[:event],
          scheduled_start: params[:scheduled_start],
          created_by: current_user.id.to_s
        }
      }
    )

    # Save to database
    user_livestream = current_user.livestreams.create!(
      pug_livestream_id: livestream.id,
      title: params[:title],
      status: 'created'
    )

    render json: {
      id: livestream.id,
      title: params[:title],
      stream_urls: livestream.stream_urls,
      playback_urls: livestream.playback_urls,
      database_id: user_livestream.id
    }, status: :created
  end

  # GET /livestreams/:id
  def show
    client = PugClient::Client.new(namespace: current_user.pug_namespace)
    client.authenticate!

    livestream = client.livestream(params[:id])

    render json: {
      id: livestream.id,
      stream_status: livestream.stream_status,
      stream_urls: livestream.stream_urls,
      playback_urls: livestream.playback_urls,
      metadata: livestream.metadata
    }
  rescue PugClient::ResourceNotFound
    render json: { error: 'Livestream not found' }, status: :not_found
  end
end
```

## Background Job Examples

### Example 1: Video Processing Job

Wait for video to finish processing:

```ruby
# app/jobs/video_processing_job.rb
class VideoProcessingJob < ApplicationJob
  queue_as :default

  # Retry on timeout or network errors
  retry_on PugClient::TimeoutError, wait: 5.minutes, attempts: 3
  retry_on PugClient::NetworkError, wait: 1.minute, attempts: 5

  def perform(video_id, namespace_id)
    # Create client
    client = PugClient::Client.new(
      namespace: namespace_id,
      connection_options: {
        request: {
          timeout: 600  # 10 minute timeout for long processing
        }
      }
    )
    client.authenticate!

    # Get video
    video = client.video(video_id)

    # Wait for processing (10 minute timeout, check every 10 seconds)
    video.wait_until_ready(timeout: 600, interval: 10)

    # Update local database
    user_video = Video.find_by(pug_video_id: video_id)
    if user_video
      user_video.update!(
        status: 'ready',
        duration: video.duration,
        playback_urls: video.playback_urls,
        thumbnail_url: video.thumbnail_url
      )

      # Send notification
      VideoMailer.processing_complete(user_video).deliver_later
    end

    Rails.logger.info "Video #{video_id} processing complete"

  rescue PugClient::TimeoutError => e
    # Video processing is taking too long
    user_video = Video.find_by(pug_video_id: video_id)
    user_video&.update(status: 'processing_timeout')

    Rails.logger.error "Video #{video_id} processing timeout: #{e.message}"
    raise  # Re-raise to trigger retry

  rescue PugClient::ResourceNotFound => e
    # Video was deleted or doesn't exist
    user_video = Video.find_by(pug_video_id: video_id)
    user_video&.update(status: 'not_found')

    Rails.logger.error "Video #{video_id} not found: #{e.message}"
    # Don't retry - video doesn't exist
  end
end
```

### Example 2: Clip Processing Job

Wait for clip to finish processing:

```ruby
# app/jobs/clip_processing_job.rb
class ClipProcessingJob < ApplicationJob
  queue_as :default

  retry_on PugClient::TimeoutError, wait: 2.minutes, attempts: 3

  def perform(clip_id, namespace_id)
    client = PugClient::Client.new(namespace: namespace_id)
    client.authenticate!

    clip = client.video(clip_id)  # Clips are videos
    clip.wait_until_ready(timeout: 300, interval: 5)

    # Update database
    user_clip = Clip.find_by(pug_clip_id: clip_id)
    if user_clip
      user_clip.update!(
        status: 'ready',
        playback_urls: clip.playback_urls,
        thumbnail_url: clip.thumbnail_url
      )

      # Notify user
      ClipMailer.ready(user_clip).deliver_later
    end
  end
end
```

### Example 3: Webhook Processing Job

Process incoming webhooks from Pug API:

```ruby
# app/jobs/pug_webhook_job.rb
class PugWebhookJob < ApplicationJob
  queue_as :webhooks

  def perform(webhook_payload)
    event_type = webhook_payload['event']
    data = webhook_payload['data']

    case event_type
    when 'video.ready'
      handle_video_ready(data)
    when 'video.failed'
      handle_video_failed(data)
    when 'livestream.started'
      handle_livestream_started(data)
    when 'livestream.ended'
      handle_livestream_ended(data)
    else
      Rails.logger.warn "Unknown webhook event: #{event_type}"
    end
  end

  private

  def handle_video_ready(data)
    video_id = data['id']
    user_video = Video.find_by(pug_video_id: video_id)

    if user_video
      user_video.update!(status: 'ready')
      VideoMailer.processing_complete(user_video).deliver_later
    end
  end

  def handle_video_failed(data)
    video_id = data['id']
    error = data['error']

    user_video = Video.find_by(pug_video_id: video_id)
    user_video&.update!(status: 'failed', error_message: error)
  end

  def handle_livestream_started(data)
    livestream_id = data['id']
    user_livestream = Livestream.find_by(pug_livestream_id: livestream_id)
    user_livestream&.update!(status: 'live')
  end

  def handle_livestream_ended(data)
    livestream_id = data['id']
    user_livestream = Livestream.find_by(pug_livestream_id: livestream_id)
    user_livestream&.update!(status: 'ended')
  end
end
```

## Error Handling

### Global Error Handling

Set up rescue handlers in `ApplicationController`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # Handle Pug API errors globally
  rescue_from PugClient::ResourceNotFound, with: :not_found
  rescue_from PugClient::ValidationError, with: :unprocessable_entity
  rescue_from PugClient::AuthenticationError, with: :unauthorized
  rescue_from PugClient::NetworkError, with: :service_unavailable
  rescue_from PugClient::TimeoutError, with: :gateway_timeout

  private

  def not_found(exception)
    render json: {
      error: 'Resource not found',
      details: exception.message
    }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: {
      error: 'Validation failed',
      details: exception.message
    }, status: :unprocessable_entity
  end

  def unauthorized(exception)
    render json: {
      error: 'Authentication failed',
      details: 'Please check your API credentials'
    }, status: :unauthorized
  end

  def service_unavailable(exception)
    render json: {
      error: 'Service unavailable',
      details: 'The video service is currently unavailable. Please try again later.'
    }, status: :service_unavailable
  end

  def gateway_timeout(exception)
    render json: {
      error: 'Request timeout',
      details: 'The operation took too long to complete'
    }, status: :gateway_timeout
  end
end
```

### Per-Action Error Handling

Handle specific errors in individual actions:

```ruby
def create
  client = pug_client
  video = client.create_video(Time.now.utc.iso8601)

  # ... upload logic ...

rescue PugClient::ValidationError => e
  # Log the error
  Rails.logger.error "Video validation failed: #{e.message}"

  # Return user-friendly error
  render json: {
    error: 'Invalid video',
    details: e.message
  }, status: :unprocessable_entity

rescue PugClient::NetworkError => e
  # Log for monitoring
  Rails.logger.error "Pug API network error: #{e.message}"
  Bugsnag.notify(e)  # Or your error tracking service

  # Return generic error
  render json: {
    error: 'Service temporarily unavailable'
  }, status: :service_unavailable
end
```

## Testing

### RSpec Controller Tests

```ruby
# spec/controllers/videos_controller_spec.rb
require 'rails_helper'

RSpec.describe VideosController, type: :controller do
  let(:user) { create(:user) }
  let(:pug_client) { instance_double(PugClient::Client) }

  before do
    sign_in user
    allow(PugClient::Client).to receive(:new).and_return(pug_client)
    allow(pug_client).to receive(:authenticate!)
  end

  describe 'POST #create' do
    let(:video) { instance_double(PugClient::Resources::Video, id: 'video-123') }

    it 'creates a video' do
      allow(pug_client).to receive(:create_video).and_return(video)
      allow(video).to receive(:upload)

      post :create, params: {
        title: 'Test Video',
        file: fixture_file_upload('video.mp4', 'video/mp4')
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['id']).to eq('video-123')
    end

    it 'handles validation errors' do
      allow(pug_client).to receive(:create_video)
        .and_raise(PugClient::ValidationError, 'Invalid video')

      post :create, params: { title: 'Test Video' }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

### VCR for Integration Tests

Use VCR to record real API interactions:

```ruby
# spec/support/vcr.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data('<PUG_CLIENT_ID>') { ENV['PUG_CLIENT_ID'] }
  config.filter_sensitive_data('<PUG_CLIENT_SECRET>') { ENV['PUG_CLIENT_SECRET'] }
end

# spec/integration/video_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'Video workflow', :vcr do
  let(:client) do
    PugClient::Client.new(
      namespace: ENV['PUG_NAMESPACE'],
      environment: :staging
    )
  end

  it 'creates and processes a video' do
    client.authenticate!

    video = client.create_video(
      Time.now.utc.iso8601,
      metadata: { labels: { test: 'integration' } }
    )

    expect(video.id).to be_present
    expect(video.metadata[:labels][:test]).to eq('integration')

    video.delete
  end
end
```

## Best Practices

### 1. Use Background Jobs for Long Operations

Never wait for video processing in web requests:

```ruby
# ❌ Bad - blocks request
def create
  video = client.create_video(Time.now.utc.iso8601)
  video.upload(file)
  video.wait_until_ready(timeout: 600)  # Blocks for up to 10 minutes!
  render json: video
end

# ✅ Good - use background job
def create
  video = client.create_video(Time.now.utc.iso8601)
  video.upload(file)
  VideoProcessingJob.perform_later(video.id, current_user.pug_namespace)
  render json: { id: video.id, status: 'processing' }
end
```

### 2. Cache Client Instances

Create client once per request:

```ruby
# ❌ Bad - creates new client every time
def index
  videos = PugClient::Client.new(namespace: current_user.pug_namespace).videos
end

def show
  video = PugClient::Client.new(namespace: current_user.pug_namespace).video(params[:id])
end

# ✅ Good - memoize client
private

def pug_client
  @pug_client ||= PugClient::Client.new(
    namespace: current_user.pug_namespace
  ).tap(&:authenticate!)
end
```

### 3. Store Pug IDs in Your Database

Maintain local records for faster queries:

```ruby
# db/migrate/xxx_create_videos.rb
class CreateVideos < ActiveRecord::Migration[7.0]
  def change
    create_table :videos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :pug_video_id, null: false, index: { unique: true }
      t.string :title
      t.string :status
      t.integer :duration
      t.jsonb :playback_urls
      t.string :thumbnail_url
      t.jsonb :metadata

      t.timestamps
    end
  end
end
```

### 4. Use Webhooks Instead of Polling

Set up webhooks to get notified when videos are ready:

```ruby
# config/routes.rb
post '/webhooks/pug', to: 'webhooks#pug'

# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:pug]

  def pug
    PugWebhookJob.perform_later(params.to_unsafe_h)
    head :ok
  end
end
```

### 5. Handle Errors Gracefully

Always handle potential errors:

```ruby
def show
  video = pug_client.video(params[:id])
  render json: video
rescue PugClient::ResourceNotFound
  render json: { error: 'Video not found' }, status: :not_found
rescue PugClient::NetworkError
  render json: { error: 'Service unavailable' }, status: :service_unavailable
end
```

### 6. Use Environment-Specific Configuration

Different configs for different environments:

```ruby
# config/initializers/pug_client.rb
PugClient.configure do |config|
  if Rails.env.production?
    config.environment = :production
    config.namespace = ENV['PUG_NAMESPACE']
  else
    config.environment = :staging
    config.namespace = ENV['PUG_STAGING_NAMESPACE'] || 'staging-namespace'
  end
end
```

## Open Questions for Follow-Up

**ActiveStorage Integration:**
- Should we provide examples showing integration with ActiveStorage?
- How to handle direct uploads vs uploading through Rails?
- Best practices for file validation before uploading to Pug?

**Error Handling:**
- Are there specific error handling patterns preferred for the ScoreVision ecosystem?
- Should we implement circuit breakers for API failures?

**Background Jobs:**
- Recommended retry strategies for video processing timeouts?
- Should we use exponential backoff for retries?
- How to handle videos that never finish processing?

**Testing:**
- Best practices for testing in CI/CD without real API calls?
- Should we provide shared RSpec helpers or test doubles?

## Related Documentation

- [README.md](../README.md) - Getting started guide
- [RESOURCES.md](RESOURCES.md) - Detailed resource documentation
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata
- [ADVANCED.md](ADVANCED.md) - Advanced topics and internals
- [Pug Video API Documentation](https://api.video.scorevision.com/ui) - Complete API reference
