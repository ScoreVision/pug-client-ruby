# Pug API Client for Ruby

A Ruby client library for the **Pug Video API** - a modern video management platform for creating, managing, and delivering video content at scale.

This gem provides an intuitive, object-oriented interface for working with video resources, livestreams, namespaces, campaigns, and more. It handles authentication, pagination, and API communication so you can focus on building great video applications.

## What Can You Do With Pug?

- Manage video resources (upload, update, delete, retrieve)
- Create and manage livestreams and campaigns
- Organize content with namespaces
- Generate signed upload URLs
- Execute video commands (clipping, processing, etc.)
- Track video metadata and labels

## Quick Start

Get up and running in 30 seconds:

```ruby
# 1. Install the gem
gem install pug-client

# 2. Set your credentials and namespace
export PUG_CLIENT_ID=your_client_id
export PUG_CLIENT_SECRET=your_client_secret
export PUG_NAMESPACE=my-videos

# 3. Use the client
require 'pug_client'

# Namespace is REQUIRED during initialization
client = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE']
)
client.authenticate!

# Access your configured namespace
namespace = client.namespace
puts "Namespace: #{namespace.id}"

# Iterate videos lazily (uses default namespace)
client.videos.each do |video|
  puts "Video #{video.id}: #{video.metadata[:title]}"
end

# Get a specific video and update it
video = client.video('video-123')
video.metadata[:labels][:status] = 'ready'
video.metadata[:labels][:featured] = true
video.save  # Auto-generates JSON Patch
```

## Table of Contents

- [Installation](#installation)
- [API Compatibility](#api-compatibility)
- [Basic Usage](#basic-usage)
- [Authentication](#authentication)
- [Working with Resources](#working-with-resources)
  - [Namespaces](#namespaces)
  - [Videos](#videos)
- [Resource API Features](#resource-api-features)
  - [Lazy Enumeration](#lazy-enumeration)
  - [Dirty Tracking](#dirty-tracking)
  - [Attribute Translation](#attribute-translation)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pug-client'
```

Or install it yourself:

```bash
gem install pug-client
```

## API Compatibility

This client library is designed for and tested against **Pug Video API version 0.4.0**.

```ruby
PugClient::API_VERSION  # => "0.4.0"
```

The library includes comprehensive integration tests recorded against the staging API using VCR cassettes. These tests validate that the client works correctly with the specified API version and serve as both verification and documentation of the expected API behavior.

**Testing Against Specific API Versions:**

Integration tests are organized by API version in `spec/integration/api_v0.4.0/`. When the API is updated, we maintain separate test suites and VCR recordings for each version to ensure compatibility and catch breaking changes.

For more information about API versions and compatibility, see the [Pug Video API documentation](https://staging-api.video.scorevision.com/openapi.json).

## Basic Usage

Here's a complete example showing the resource-based API:

```ruby
require 'pug_client'

# 1. Create a client with namespace (REQUIRED)
client = PugClient::Client.new(
  namespace: 'my-videos',
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
)

# 2. Authenticate (gets an OAuth access token)
client.authenticate!

# 3. Work with your configured namespace
namespace = client.namespace  # Uses default namespace
puts "Namespace: #{namespace.id}"
puts "Created at: #{namespace.created_at}"

# Or access a different namespace
other_namespace = client.namespace('other-videos')

# 4. Work with videos (uses default namespace)
video = client.video('video-123')
puts "Video: #{video.id}"

# Or override namespace for specific calls
video = client.video('video-456', namespace: 'other-videos')

# 5. Update video naturally with dirty tracking
video.metadata[:labels][:status] = 'processed'
video.metadata[:labels][:featured] = true
video.save  # Automatically generates JSON Patch operations

# 6. Create a clip from video
clip = video.clip(start_time: 5000, duration: 30000,
  metadata: { labels: { type: 'highlight' } }
)
puts "Created clip: #{clip.id}"

# 7. Upload a file (MP4 only currently)
File.open('video.mp4', 'rb') do |file|
  video.upload(file, filename: 'video.mp4')
end
video.wait_until_ready(timeout: 600)
puts "Video ready: #{video.playback_urls}"

# 8. Iterate videos lazily (fetches pages on-demand, uses default namespace)
client.videos.each do |video|
  puts "Video: #{video.id}"
end

# Or get first N videos
recent_videos = client.videos.first(10)

# Override namespace for listings
other_videos = client.videos(namespace: 'other-videos').first(10)

# 9. Delete video
video.delete
```

## Authentication

The client uses **Auth0's client credentials flow** for machine-to-machine authentication. You'll need API credentials (client ID and secret) from your Pug account.

### Three Ways to Provide Credentials

**1. Environment Variables (Recommended for Production)**

```ruby
# Set in your environment:
# export PUG_CLIENT_ID=your_client_id
# export PUG_CLIENT_SECRET=your_client_secret
# export PUG_NAMESPACE=my-videos

client = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE']  # Required
)
client.authenticate!
```

**2. Pass Directly (Good for Testing)**

```ruby
client = PugClient::Client.new(
  namespace: 'my-videos',  # Required
  client_id: 'your_client_id',
  client_secret: 'your_client_secret'
)
client.authenticate!
```

**3. Global Configuration (For Singleton Pattern)**

```ruby
PugClient.configure do |c|
  c.namespace = 'my-videos'  # Required
  c.client_id = 'your_client_id'
  c.client_secret = 'your_client_secret'
end

# Now use module-level methods
PugClient.authenticate!
namespace = PugClient.namespace  # Uses configured namespace
```

### Managing Authentication

```ruby
# Check if authenticated
client.authenticated? # => true/false

# Check if token is expired
client.token_expired? # => true/false

# Auto-refresh token if needed (recommended before API calls)
client.ensure_authenticated!

# Manually refresh token
client.authenticate!
```

## Working with Resources

### Namespaces

Namespaces help organize your video content. Think of them as folders or projects. The resource-based API makes working with namespaces intuitive and object-oriented.

**Important:** A namespace ID is required when creating a client and serves as the default for all operations. You'll use an existing namespace that's been set up for your account.

```ruby
# Create client with default namespace (REQUIRED - use existing namespace ID)
client = PugClient::Client.new(
  namespace: 'my-videos',  # Your existing namespace ID
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
)

# Get your configured namespace (no ID needed)
namespace = client.namespace
puts namespace.id         # => "my-videos"
puts namespace.metadata

# Get a different namespace by ID
other = client.namespace('other-videos')

# Update namespace metadata (with automatic dirty tracking)
namespace.metadata[:labels][:status] = 'active'
namespace.metadata[:annotations] = { project: 'v2' }
namespace.save  # Generates and sends JSON Patch automatically

# Reload from API (discards unsaved changes)
namespace.reload
puts namespace.metadata

# List all namespaces you have access to (returns lazy enumerator)
client.namespaces.each do |ns|
  puts "Namespace: #{ns.id}"
end

# List user's namespaces
client.user_namespaces.first(10)
```

### Videos

Videos are the core resource. Each video belongs to a namespace and uses the powerful resource-based API for natural, Ruby-idiomatic operations.

**Two ways to work with videos:**
1. Through the client (uses configured default namespace)
2. Through a namespace object (uses that namespace's ID)

```ruby
# Setup: Client with default namespace
client = PugClient::Client.new(
  namespace: 'my-videos',
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
)

# Way 1: Use client directly (uses default namespace 'my-videos')
video = client.video('video-123')
puts video.id

# Override namespace for specific calls
video = client.video('video-456', namespace: 'other-videos')

# Way 2: Use namespace object
namespace = client.namespace
video = namespace.video('video-123')  # Same as client.video('video-123')

# Update video metadata (automatic dirty tracking + JSON Patch)
video.metadata[:labels][:status] = 'processed'
video.metadata[:labels][:featured] = true
video.save  # Auto-generates: [
            #   {op: 'add', path: '/attributes/metadata/labels/status', value: 'processed'},
            #   {op: 'add', path: '/attributes/metadata/labels/featured', value: true}
            # ]

# Upload a video file (MP4 only currently)
File.open('video.mp4', 'rb') do |file|
  video.upload(file, filename: 'video.mp4')
end

# Wait for video processing to complete
video.wait_until_ready(timeout: 600, interval: 5)
puts "Video ready! Playback URLs: #{video.playback_urls}"

# Create a clip from a video (returns NEW video resource)
clip = video.clip(
  start_time: 10000,  # Start at 10 seconds (milliseconds)
  duration: 30000,    # 30 second clip
  metadata: { labels: { type: 'highlight' } }
)
puts "Created clip: #{clip.id}"

# You can work with the clip like any other video
clip.metadata[:labels][:featured] = true
clip.save

# Get the parent namespace of a video
parent = video.namespace
puts "Video belongs to: #{parent.id}"

# Iterate videos (both approaches work)
client.videos.each do |video|                    # Uses default namespace
  puts "Video #{video.id}: #{video.started_at}"
end

namespace.videos.each do |video|                 # Uses namespace's ID
  puts "Video #{video.id}: #{video.started_at}"
end

# Override namespace for listings
client.videos(namespace: 'other-videos').each { |v| puts v.id }

# Get first N videos efficiently
recent_videos = client.videos.first(10)

# Force eager loading if needed
all_videos = client.videos.to_a

# Filter videos (still lazy)
ready_videos = client.videos.select { |v| v.status == 'ready' }

# Delete a video
video.delete

# Reload video from API (discards local changes)
video.reload
```

### Read-Only Attributes

Some attributes cannot be modified after creation:

**Namespace:** `id`, `created_at`, `updated_at`
**Video:** `id`, `created_at`, `updated_at`, `duration`, `renditions`, `playback_urls`, `thumbnail_url`

```ruby
video.id = 'new-id'  # Raises ValidationError
video.duration = 90000  # Raises ValidationError

# But you can read them
puts video.duration
puts video.playback_urls
```

## Resource API Features

### Lazy Enumeration

Resource collections use Ruby's Enumerator pattern for efficient, on-demand pagination:

```ruby
# Fetches pages as you iterate (memory efficient for large datasets)
namespace.videos.each do |video|
  puts video.id
  break if video.id == 'target-id'  # Stops fetching
end

# Get first N (only fetches enough pages)
recent = namespace.videos.first(10)

# Full Enumerable interface
ids = namespace.videos.map(&:id)
featured = namespace.videos.select { |v| v.metadata[:labels][:featured] }
count = namespace.videos.count  # Note: fetches all pages

# Force eager loading when needed
all_videos = namespace.videos.to_a
```

### Dirty Tracking

Resources automatically track changes and generate JSON Patch operations:

```ruby
video = client.video('my-namespace', 'video-123')

# Make multiple changes
video.metadata[:labels][:status] = 'ready'
video.metadata[:labels][:reviewed] = true
video.metadata[:annotations] = { reviewer: 'john@example.com' }

# Check if changed
video.changed?  # => true

# Save sends JSON Patch automatically
video.save  # Generates:
           # [
           #   {op: 'add', path: '/attributes/metadata/labels/status', value: 'ready'},
           #   {op: 'add', path: '/attributes/metadata/labels/reviewed', value: true},
           #   {op: 'add', path: '/attributes/metadata/annotations', value: {...}}
           # ]

# After save, no longer dirty
video.changed?  # => false

# Reload discards unsaved changes
video.metadata[:labels][:new] = 'value'
video.reload  # Local changes discarded, fresh from API
```

### Attribute Translation

The API uses camelCase, but Ruby code uses snake_case:

```ruby
# API returns: { data: { attributes: { startedAt: '...' } } }
# Ruby sees:
video.started_at  # Automatic translation

# When you update:
video.metadata[:created_by] = 'user@example.com'
# Sent to API as: { createdBy: 'user@example.com' }
```

## Configuration

### Environment Configuration

Pug provides preset configurations for production and staging environments.

**Production (Default)**

```ruby
client = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE'],  # Required
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
  # Uses production endpoints automatically
)
```

**Staging**

```ruby
# Option 1: Pass environment parameter
client = PugClient::Client.new(
  environment: :staging,
  namespace: ENV['PUG_NAMESPACE'],  # Required
  client_id: ENV['PUG_STAGING_CLIENT_ID'],
  client_secret: ENV['PUG_STAGING_CLIENT_SECRET']
)

# Option 2: Use global configuration
PugClient.use_staging!
PugClient.configure do |c|
  c.namespace = ENV['PUG_NAMESPACE']  # Required
  c.client_id = ENV['PUG_STAGING_CLIENT_ID']
  c.client_secret = ENV['PUG_STAGING_CLIENT_SECRET']
end
```

**Custom/Local Development**

For custom environments (local development, custom deployments), pass all endpoints explicitly:

```ruby
client = PugClient::Client.new(
  namespace: 'test-namespace',  # Required
  api_endpoint: 'http://localhost:3000',
  auth_endpoint: 'http://localhost:3001/oauth/token',
  auth_audience: 'http://localhost:3000/',
  auth_grant_type: 'client_credentials',
  client_id: 'local_client_id',
  client_secret: 'local_client_secret'
)
```

### Environment Defaults

| Setting | Production | Staging |
|---------|-----------|---------|
| API Endpoint | `https://api.video.scorevision.com` | `https://staging-api.video.scorevision.com` |
| Auth Endpoint | `https://fantagio.auth0.com/oauth/token` | `https://fantagio-staging.auth0.com/oauth/token` |
| Auth Audience | `https://api.fantag.io/` | `https://staging-api.fantag.io/` |

### Configuration Options Reference

All available configuration options:

```ruby
PugClient::Client.new(
  # Namespace (REQUIRED)
  namespace: 'my-videos',               # Default namespace for all operations (required)

  # Environment (preset configurations)
  environment: :production,              # :production (default) or :staging

  # Authentication (required)
  client_id: 'your_client_id',          # OAuth client ID
  client_secret: 'your_client_secret',  # OAuth client secret
  access_token: 'manual_token',         # Optional: skip auth flow with existing token

  # Endpoints (auto-set by environment, or specify manually)
  api_endpoint: 'https://...',          # API base URL
  auth_endpoint: 'https://...',         # Auth0 token endpoint
  auth_audience: 'https://...',         # Auth0 audience
  auth_grant_type: 'client_credentials', # OAuth grant type

  # Pagination
  per_page: 10,                         # Default page size (default: 10)

  # HTTP Configuration
  connection_options: {                 # Faraday options
    request: {
      open_timeout: 5,                  # Connection timeout
      timeout: 10                       # Read timeout
    }
  }
)
```

## Advanced Usage

### Module-Level API

Use the module-level API for a singleton-style interface:

```ruby
# Configure once (namespace is required)
PugClient.configure do |c|
  c.namespace = ENV['PUG_NAMESPACE']  # Required
  c.client_id = ENV['PUG_CLIENT_ID']
  c.client_secret = ENV['PUG_CLIENT_SECRET']
end

# Use anywhere
PugClient.authenticate!

# Access configured namespace
namespace = PugClient.namespace
videos = namespace.videos.to_a

# Or use client methods directly (uses configured namespace)
videos = PugClient.videos.to_a
video = PugClient.video('video-123')
```

### Error Handling

The gem provides specific error classes for better error handling:

```ruby
begin
  video = client.video('non-existent')
rescue PugClient::ResourceNotFound => e
  puts "Video not found: #{e.resource_type} #{e.id}"
rescue PugClient::NetworkError => e
  puts "Network error: #{e.message}"
rescue PugClient::AuthenticationError => e
  puts "Auth error: #{e.message}"
end

# Namespace requirement validation
begin
  client = PugClient::Client.new(
    client_id: ENV['PUG_CLIENT_ID'],
    client_secret: ENV['PUG_CLIENT_SECRET']
    # Missing required namespace parameter
  )
rescue ArgumentError => e
  puts e.message  # => "namespace is required"
end

# Upload validation
begin
  video.upload(file, filename: 'video.avi', content_type: 'video/avi')
rescue PugClient::ValidationError => e
  puts "Invalid upload: #{e.message}"
  # => "Unsupported content type: video/avi. Currently only video/mp4 is supported."
end

# Wait timeout
begin
  video.wait_until_ready(timeout: 60)
rescue PugClient::TimeoutError => e
  puts "Video processing took too long: #{e.message}"
end
```

### Low-Level HTTP Methods

For resources not yet supported by dedicated resource classes (livestreams, campaigns, etc.), use the low-level HTTP interface:

```ruby
# GET request
response = client.get('livestreams')

# POST request (with JSON:API formatted body)
response = client.post('livestreams', {
  data: {
    type: 'livestreams',
    attributes: {
      title: 'My Livestream'
    }
  }
})

# PATCH request (JSON Patch format)
response = client.patch("livestreams/123", [
  { op: 'replace', path: '/attributes/title', value: 'Updated Title' }
])

# DELETE request
client.delete("livestreams/123")

# Access response details
puts client.last_response.status        # HTTP status code
puts client.last_response.headers       # Response headers
```

## Troubleshooting

### Authentication Errors

**Problem:** `PugClient::AuthenticationError: Authentication failed`

**Solutions:**
- Verify your `client_id` and `client_secret` are correct
- Check that you're using the right environment (production vs staging credentials)
- Ensure your credentials haven't expired or been revoked
- Try authenticating manually: `client.authenticate!`

```ruby
# Debug authentication
begin
  client.authenticate!
  puts "Authenticated successfully!"
rescue PugClient::AuthenticationError => e
  puts "Auth failed: #{e.message}"
  puts "Using client_id: #{client.client_id}"
  puts "Auth endpoint: #{client.auth_endpoint}"
end
```

### Token Expiration

**Problem:** Getting 401 errors after initial authentication

**Solution:** Tokens expire after a certain time. Use `ensure_authenticated!` before API calls:

```ruby
# Automatically refresh if expired
client.ensure_authenticated!
namespace = client.namespace('my-videos')

# Or check manually
if client.token_expired?
  client.authenticate!
end
```

### Resource Not Found

**Problem:** `PugClient::ResourceNotFound` error

**Solutions:**
- Verify the resource exists: `client.videos.each { |v| puts v.id }`
- Check for typos in the resource ID
- Ensure you have permission to access the resource
- Verify you're using the correct environment (production vs staging)
- Confirm you're using the correct namespace: `client.namespace.id`

### Upload Errors

**Problem:** Upload fails or content type rejected

**Solutions:**
- Only MP4 format is currently supported: `content_type: 'video/mp4'`
- Ensure file is readable: `File.open('video.mp4', 'rb')`
- Check file size and timeout settings
- Verify video processing with `wait_until_ready`

### Connection Timeouts

**Problem:** Requests timing out

**Solution:** Increase timeout values:

```ruby
client = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE'],
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET'],
  connection_options: {
    request: {
      open_timeout: 10,  # Increase from default
      timeout: 30        # Increase from default
    }
  }
)
```

## API Design

This gem uses a **resource-based API design** for core resources (Namespace, Video), providing:

- **Object-oriented interface** - Resources are first-class Ruby objects
- **Lazy enumeration** - Efficient iteration over large collections
- **Automatic dirty tracking** - Changes tracked and converted to JSON Patch
- **Idiomatic Ruby** - snake_case attributes, natural mutations, Enumerable support

Other resources (livestreams, campaigns, webhooks, etc.) currently use the client-centric API. These will be migrated to the resource-based pattern in future versions.

## Requirements

- Ruby >= 3.4
- Faraday >= 2.14
- Sawyer ~> 0.9

## Contributing

Contributions are welcome! If you want to contribute to this gem, please see [DEVELOPING.md](DEVELOPING.md) for development setup, architecture details, and guidelines for adding new features.

## License

This project is licensed under the MIT License - see the [gemspec](pug-client.gemspec) for details.

## Links

- **Homepage**: http://git.scorevision.com/fantag/pug-client-ruby
- **Issues**: http://git.scorevision.com/fantag/pug-client-ruby/issues
- **Development Guide**: [DEVELOPING.md](DEVELOPING.md)
