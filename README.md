# Pug API Client for Ruby

A Ruby client library for the **Pug Video API** - a modern video management platform for creating, managing, and delivering video content at scale.

This gem provides an intuitive, object-oriented interface for working with video resources, livestreams, namespaces, campaigns, and more. It handles authentication, pagination, and API communication so you can focus on building great video applications.

## What Can You Do With Pug?

- **Manage video resources** - Upload, update, delete, and retrieve videos
- **Create and manage livestreams** - Live video streaming with real-time playback
- **Simulcast/Restream** - Broadcast to multiple platforms simultaneously (YouTube, Facebook, Twitch, custom RTMP)
- **Organize content** - Use namespaces to organize videos into logical groups
- **Generate upload URLs** - Secure, signed URLs for direct client uploads
- **Execute video commands** - Create clips from existing videos
- **Track metadata** - Rich labeling and annotation system for categorization
- **Webhooks** - Real-time notifications for video events

## Quick Start

Get up and running in 30 seconds:

```bash
# 1. Install the gem
gem install pug-client

# 2. Set your credentials and namespace
export PUG_CLIENT_ID=your_client_id
export PUG_CLIENT_SECRET=your_client_secret
export PUG_NAMESPACE=my-videos

# 3. Use the client
```

```ruby
require 'pug_client'

# Create client (automatically uses ENV vars)
client = PugClient::Client.new(namespace: ENV['PUG_NAMESPACE'])
client.authenticate!

# Access your namespace
namespace = client.namespace
puts "Namespace: #{namespace.id}"

# List videos (lazy iteration)
client.videos.first(10).each do |video|
  puts "Video #{video.id}: #{video.metadata[:labels][:title]}"
end

# Get and update a video
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
video.metadata[:labels][:status] = 'ready'
video.metadata[:labels][:featured] = true
video.save  # Auto-generates JSON Patch

# Upload a new video
video = client.create_video(Time.now.utc.iso8601)
File.open('game.mp4', 'rb') { |f| video.upload(f, filename: 'game.mp4') }
video.wait_until_ready(timeout: 600)
puts "Playback URLs: #{video.playback_urls}"
```

## Table of Contents

- [Installation](#installation)
- [API Compatibility](#api-compatibility)
- [Authentication](#authentication)
- [Basic Usage](#basic-usage)
- [Resources](#resources)
- [Key Features](#key-features)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Documentation](#documentation)

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

The library includes comprehensive integration tests recorded against the API using VCR cassettes. All integration tests are located in `spec/integration/`, and VCR cassettes are versioned by API in `spec/cassettes/api_v0.4.0/`.

## Authentication

The client uses **Auth0's client credentials flow** for machine-to-machine authentication. Tokens are automatically refreshed before each API request, so you don't need to manually manage token expiration.

### Automatic Credentials from Environment

The gem automatically reads credentials from environment variables:

```bash
export PUG_CLIENT_ID=your_client_id
export PUG_CLIENT_SECRET=your_client_secret
export PUG_NAMESPACE=my-videos
```

```ruby
# Credentials loaded automatically from ENV
client = PugClient::Client.new(namespace: ENV['PUG_NAMESPACE'])
client.authenticate!
```

### Explicit Credentials

You can also pass credentials directly:

```ruby
client = PugClient::Client.new(
  namespace: 'my-videos',
  client_id: 'your_client_id',
  client_secret: 'your_client_secret'
)
client.authenticate!
```

### Global Configuration (Singleton Pattern)

```ruby
PugClient.configure do |c|
  c.namespace = 'my-videos'
  c.client_id = 'your_client_id'
  c.client_secret = 'your_client_secret'
end

PugClient.authenticate!

# Use module-level methods
namespace = PugClient.namespace
videos = PugClient.videos.first(10)
```

**Note:** Authentication tokens are automatically refreshed before every API request, so you don't need to manually check token expiration or call `ensure_authenticated!`.

## Basic Usage

### Complete Example

```ruby
require 'pug_client'

# Create client with namespace (required)
client = PugClient::Client.new(namespace: 'my-videos')
client.authenticate!

# Get your namespace
namespace = client.namespace
puts "Namespace: #{namespace.id}"

# Create and upload a video
video = client.create_video(
  Time.now.utc.iso8601,
  metadata: {
    labels: {
      title: 'Championship Game',
      team: 'eagles',
      game_date: '2025-01-15'
    }
  }
)

File.open('game.mp4', 'rb') { |f| video.upload(f, filename: 'game.mp4') }
video.wait_until_ready(timeout: 600)
puts "Video ready: #{video.playback_urls}"

# Update video metadata
video.metadata[:labels][:status] = 'published'
video.metadata[:labels][:featured] = true
video.save  # Automatically generates JSON Patch operations

# Create a clip (highlight)
clip = video.clip(
  start_time: 120000,  # 2 minutes
  duration: 30000,     # 30 seconds
  metadata: { labels: { type: 'touchdown' } }
)

# List videos efficiently
client.videos.first(20).each do |v|
  puts "#{v.id}: #{v.metadata[:labels][:title]}"
end

# Delete video
video.delete
```

## Resources

All resources follow a consistent, object-oriented pattern with automatic dirty tracking, lazy enumeration, and natural Ruby idioms.

### Available Resources

- **[Namespaces](docs/NAMESPACES.md)** - Organize content into logical groups
- **[Videos](docs/VIDEOS.md)** - Core video management with upload, playback, and clipping
- **[LiveStreams](docs/LIVESTREAMS.md)** - Real-time video streaming
- **[Campaigns](docs/CAMPAIGNS.md)** - Ad campaigns with pre-roll/post-roll videos
- **[Playlists](docs/PLAYLISTS.md)** - Ordered collections for sequential playback
- **[Webhooks](docs/WEBHOOKS.md)** - Real-time event notifications
- **[Simulcast Targets](docs/SIMULCAST_TARGETS.md)** - Restream to multiple platforms (YouTube, Facebook, Twitch, custom RTMP)

### Common Resource Patterns

All resources support:

```ruby
# Find by ID (uses configured namespace)
resource = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Override namespace for specific call
resource = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5', namespace: 'other-namespace')

# Update with automatic dirty tracking
resource.metadata[:labels][:status] = 'ready'
resource.save  # Generates JSON Patch automatically

# Reload from API
resource.reload

# Delete resource
resource.delete

# List resources lazily
client.videos.first(20).each { |v| puts v.id }
```

**See [RESOURCES.md](docs/RESOURCES.md) for an overview and links to detailed guides for each resource type.**

## Key Features

### Automatic Dirty Tracking

Resources automatically track changes and generate JSON Patch operations:

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Make multiple changes
video.metadata[:labels][:status] = 'ready'
video.metadata[:labels][:reviewed] = true
video.metadata[:labels][:featured] = true

# Check if changed
video.changed?  # => true

# Save sends JSON Patch automatically
video.save
# Generates: [
#   {op: 'add', path: '/attributes/metadata/labels/status', value: 'ready'},
#   {op: 'add', path: '/attributes/metadata/labels/reviewed', value: true},
#   {op: 'add', path: '/attributes/metadata/labels/featured', value: true}
# ]

video.changed?  # => false (clean after save)
```

**Learn more:** [ADVANCED.md#dirty-tracking](docs/ADVANCED.md#dirty-tracking)

### Lazy Enumeration

Collections use Ruby's Enumerator pattern for efficient, on-demand pagination:

```ruby
# Fetches pages as you iterate (memory efficient)
client.videos.each do |video|
  puts video.id
  break if condition  # Stops fetching additional pages
end

# Get first N (only fetches necessary pages)
recent_videos = client.videos.first(20)

# Explicitly fetch all (warning: may fetch thousands of records)
all_videos = client.videos.to_a
```

**Learn more:** [ADVANCED.md#lazy-enumeration](docs/ADVANCED.md#lazy-enumeration)

### Attribute Translation

The API uses camelCase, but Ruby code uses snake_case - translation is automatic:

```ruby
# API returns: { startedAt: '...', playbackUrls: {...} }
# Ruby sees:
video.started_at
video.playback_urls

# Ruby sends: { metadata: { labels: { created_by: 'user' } } }
# API receives: { metadata: { labels: { createdBy: 'user' } } }
```

**Learn more:** [ADVANCED.md#attribute-translation](docs/ADVANCED.md#attribute-translation)

### Metadata: Labels vs Annotations

The API provides two metadata fields with different purposes:

**Labels** - User-defined categorization (for API consumers):
```ruby
video.metadata[:labels] = {
  team: 'eagles',
  highlight_type: 'touchdown',
  quarter: '4',
  featured: true
}
```

**Annotations** - System-generated metadata (for backend use):
```ruby
# Automatically set by the system
clip.metadata[:annotations]
# => {
#   "scorevision.com/command": "clip",
#   "scorevision.com/command_source": "video-123"
# }
```

**Learn more:** [API_LIMITATIONS.md#metadata-structure](docs/API_LIMITATIONS.md#metadata-structure)

## Configuration

### Environment Configuration

**Production (Default):**
```ruby
client = PugClient::Client.new(namespace: 'my-videos')
# Uses production endpoints automatically
```

**Staging:**
```ruby
client = PugClient::Client.new(
  environment: :staging,
  namespace: 'my-videos'
)
```

### Environment Endpoints

| Setting | Production | Staging |
|---------|-----------|---------|
| API Endpoint | `https://api.video.scorevision.com` | `https://staging-api.video.scorevision.com` |
| Auth Endpoint | `https://fantagio.auth0.com/oauth/token` | `https://fantagio-staging.auth0.com/oauth/token` |
| Auth Audience | `https://api.fantag.io/` | `https://staging-api.fantag.io/` |

### Configuration Options

```ruby
client = PugClient::Client.new(
  # Required
  namespace: 'my-videos',

  # Environment preset
  environment: :production,  # or :staging

  # Authentication (defaults from ENV)
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET'],

  # Optional: Pagination
  per_page: 20,

  # Optional: HTTP timeouts
  connection_options: {
    request: {
      open_timeout: 10,
      timeout: 30
    }
  }
)
```

**Learn more:** [ADVANCED.md#configuration](docs/ADVANCED.md#configuration)

## Error Handling

The gem provides specific error classes for graceful error handling:

```ruby
begin
  video = client.video('00000000-0000-0000-0000-000000000000')
rescue PugClient::ResourceNotFound => e
  puts "Video not found: #{e.message}"
rescue PugClient::ValidationError => e
  puts "Validation error: #{e.message}"
rescue PugClient::NetworkError => e
  puts "Network error: #{e.message}"
rescue PugClient::AuthenticationError => e
  puts "Auth error: #{e.message}"
rescue PugClient::TimeoutError => e
  puts "Timeout: #{e.message}"
end
```

**Available error classes:**
- `AuthenticationError` - OAuth authentication failed
- `ResourceNotFound` - Resource doesn't exist (404)
- `ValidationError` - Invalid data or modifications
- `NetworkError` - HTTP/network failures
- `TimeoutError` - Wait operations exceeded timeout
- `ResourceFrozenError` - Attempted to modify frozen/deleted resource
- `FeatureNotSupportedError` - Intentionally unsupported endpoints

**Learn more:** [ADVANCED.md#error-handling](docs/ADVANCED.md#error-handling)

## Documentation

### Complete Documentation

- **[RESOURCES.md](docs/RESOURCES.md)** - Overview and index of all resource guides
  - [Namespaces](docs/NAMESPACES.md), [Videos](docs/VIDEOS.md), [LiveStreams](docs/LIVESTREAMS.md), [Campaigns](docs/CAMPAIGNS.md), [Playlists](docs/PLAYLISTS.md), [Webhooks](docs/WEBHOOKS.md), [Simulcast Targets](docs/SIMULCAST_TARGETS.md)
- **[VIDEO_PROCESSING.md](docs/VIDEO_PROCESSING.md)** - Complete technical reference for video formats, transcoding specifications, and processing pipeline
- **[API_LIMITATIONS.md](docs/API_LIMITATIONS.md)** - API constraints, metadata structure, rate limits, and file size limits
- **[ADVANCED.md](docs/ADVANCED.md)** - Deep dive into dirty tracking, lazy enumeration, attribute translation, error handling, configuration
- **[RAILS_INTEGRATION.md](docs/RAILS_INTEGRATION.md)** - Rails-specific examples (controllers, background jobs, testing)
- **[CLAUDE.md](https://git.scorevision.com/fantag/pug-client-ruby/-/blob/main/CLAUDE.md)** - Development guide and architecture details

### API Documentation

- **Production API:** [https://api.video.scorevision.com/ui](https://api.video.scorevision.com/ui)
- **Staging API:** [https://staging-api.video.scorevision.com/ui](https://staging-api.video.scorevision.com/ui)

### YARD Documentation

Generate API documentation with YARD:

```bash
bundle exec yard doc
open doc/index.html
```

## Requirements

- Ruby >= 3.4
- Faraday >= 2.14
- Sawyer ~> 0.9

## Contributing

Contributions are welcome! If you want to contribute to this gem, please see [CLAUDE.md](https://git.scorevision.com/fantag/pug-client-ruby/-/blob/main/CLAUDE.md) for development setup, architecture details, and guidelines for adding new features.

## License

This project is licensed under the MIT License - see the [gemspec](https://git.scorevision.com/fantag/pug-client-ruby/-/blob/main/pug-client.gemspec) for details.

## Links

- **Homepage:** [https://git.scorevision.com/fantag/pug-client-ruby](https://git.scorevision.com/fantag/pug-client-ruby)
- **Issues:** [https://git.scorevision.com/fantag/pug-client-ruby/-/issues](https://git.scorevision.com/fantag/pug-client-ruby/-/issues)
- **Documentation:** [https://gitdoc.scorevision.com/fantag/pug-client-ruby/](https://gitdoc.scorevision.com/fantag/pug-client-ruby/)
- **Development Guide:** [CLAUDE.md](https://git.scorevision.com/fantag/pug-client-ruby/-/blob/main/CLAUDE.md)
