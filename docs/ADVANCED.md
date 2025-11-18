# Advanced Topics

This document covers advanced features, internal mechanisms, and deep-dive topics for the Pug Video API Ruby client.

## Table of Contents

- [Dirty Tracking](#dirty-tracking)
- [Attribute Translation](#attribute-translation)
- [Lazy Enumeration](#lazy-enumeration)
- [Automatic Authentication](#automatic-authentication)
- [Error Handling](#error-handling)
- [Low-Level HTTP Methods](#low-level-http-methods)
- [Configuration](#configuration)
- [Module-Level vs Instance-Level API](#module-level-vs-instance-level-api)

## Dirty Tracking

The client automatically tracks changes to resources and generates [RFC 6902 JSON Patch](https://tools.ietf.org/html/rfc6902) operations when you call `save`.

### How It Works

1. **Snapshot Original State**: When a resource is loaded from the API, its attributes are stored as `@original_attributes`
2. **Track Mutations**: When you modify attributes (even nested ones), the resource is marked as "dirty"
3. **Generate Patch**: On `save`, the client compares current vs original attributes and generates JSON Patch operations
4. **Send Patch**: The PATCH request is sent to the API with the operations
5. **Update State**: After successful save, the new state becomes the original state and the dirty flag is cleared

### Example: Simple Attribute Change

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
puts video.changed?  # => false

# Make a simple change
video.metadata[:labels][:status] = 'ready'
puts video.changed?  # => true

# Save generates and sends JSON Patch
video.save
# API receives:
# [
#   {
#     "op": "add",
#     "path": "/attributes/metadata/labels/status",
#     "value": "ready"
#   }
# ]

puts video.changed?  # => false (clean after save)
```

### Example: Nested Hash Mutations

The dirty tracking system uses `TrackedHash` to detect changes at any depth:

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Nested mutations are tracked
video.metadata[:labels][:team] = 'eagles'
video.metadata[:labels][:player] = {
  name: 'Tom Brady',
  number: 12
}

# Even deep modifications
video.metadata[:labels][:stats] ||= {}
video.metadata[:labels][:stats][:touchdowns] = 3
video.metadata[:labels][:stats][:yards] = 250

puts video.changed?  # => true

# Save generates multiple patch operations
video.save
# API receives:
# [
#   { "op": "add", "path": "/attributes/metadata/labels/team", "value": "eagles" },
#   { "op": "add", "path": "/attributes/metadata/labels/player", "value": {...} },
#   { "op": "add", "path": "/attributes/metadata/labels/stats", "value": {...} }
# ]
```

### TrackedHash Implementation

All Hash values are automatically wrapped in `TrackedHash`, which:
- Notifies the parent resource when modified
- Recursively wraps nested hashes
- Tracks all mutations (assignment, merge, delete, etc.)

```ruby
# When you load a resource:
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
# video.metadata is a TrackedHash
# video.metadata[:labels] is also a TrackedHash

# Any modification triggers dirty tracking:
video.metadata[:labels][:new_key] = 'value'  # Tracked
video.metadata[:labels].merge!({ key: 'value' })  # Tracked
video.metadata[:labels].delete(:old_key)  # Tracked
```

### Checking Changes

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Check if resource has changed
video.changed?  # => false

# Make changes
video.metadata[:labels][:status] = 'ready'

# Check again
video.changed?  # => true

# Get list of changes (internal method)
# changes = video.changes  # Returns array of { path, old_value, new_value }
```

### Discarding Changes

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
video.metadata[:labels][:status] = 'draft'

# Discard local changes and reload from API
video.reload

# Changed flag is cleared and attributes reset
puts video.changed?  # => false
```

### Read-Only Attributes

Attempting to modify read-only attributes raises `ValidationError`:

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# These are read-only and will raise errors
video.id = 'new-id'  # => PugClient::ValidationError
video.duration = 90000  # => PugClient::ValidationError
video.created_at = Time.now  # => PugClient::ValidationError

# But you can read them
puts video.id
puts video.duration
puts video.created_at
```

## Attribute Translation

The Pug API uses `camelCase` for attribute names (JSON:API standard), but Ruby conventionally uses `snake_case`. The client automatically translates between the two.

### How It Works

1. **API → Ruby**: When receiving data from the API, `camelCase` keys are converted to `snake_case`
2. **Ruby → API**: When sending data to the API, `snake_case` keys are converted to `camelCase`
3. **Nested Structures**: Translation happens recursively through nested hashes and arrays

### Example: API Response Translation

```ruby
# API returns:
# {
#   "data": {
#     "type": "videos",
#     "attributes": {
#       "startedAt": "2025-01-15T10:00:00Z",
#       "createdAt": "2025-01-15T10:00:00Z",
#       "playbackUrls": {
#         "hlsUrl": "https://...",
#         "dashUrl": "https://..."
#       },
#       "metadata": {
#         "labels": {
#           "createdBy": "user@example.com"
#         }
#       }
#     }
#   }
# }

video = client.video('video-123')

# Ruby sees snake_case:
puts video.started_at     # From startedAt
puts video.created_at     # From createdAt
puts video.playback_urls[:hls_url]  # From playbackUrls.hlsUrl
puts video.metadata[:labels][:created_by]  # From metadata.labels.createdBy
```

### Example: Ruby → API Translation

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# You write in snake_case:
video.metadata[:labels][:created_by] = 'user@example.com'
video.metadata[:labels][:publish_date] = '2025-01-15'
video.metadata[:labels][:is_featured] = true

# API receives in camelCase:
# {
#   "data": {
#     "type": "videos",
#     "attributes": {
#       "metadata": {
#         "labels": {
#           "createdBy": "user@example.com",
#           "publishDate": "2025-01-15",
#           "isFeatured": true
#         }
#       }
#     }
#   }
# }
```

### Nested Structure Translation

```ruby
# Create video with deeply nested metadata
video = client.create_video(
  Time.now.utc.iso8601,
  metadata: {
    labels: {
      game_info: {
        home_team: 'eagles',
        away_team: 'patriots',
        final_score: { home: 24, away: 21 }
      },
      player_stats: {
        quarterback: {
          pass_attempts: 35,
          completions: 28,
          passing_yards: 320
        }
      }
    }
  }
)

# All keys are converted to camelCase for the API:
# {
#   "metadata": {
#     "labels": {
#       "gameInfo": {
#         "homeTeam": "eagles",
#         "awayTeam": "patriots",
#         "finalScore": { "home": 24, "away": 21 }
#       },
#       "playerStats": {
#         "quarterback": {
#           "passAttempts": 35,
#           "completions": 28,
#           "passingYards": 320
#         }
#       }
#     }
#   }
# }
```

### Important Notes

1. **Always use snake_case in Ruby code**: The client handles conversion automatically
2. **Metadata structure**: Both `labels` and `annotations` follow the same translation rules
3. **Array values**: Arrays are traversed and any hash elements are translated
4. **Primitive values**: Numbers, strings, booleans, and nil are not affected by translation

## Lazy Enumeration

Resource collections use Ruby's `Enumerator` pattern for memory-efficient, on-demand pagination.

### How It Works

1. **No Immediate Request**: Calling `.videos` doesn't make an API request
2. **On-Demand Fetching**: Pages are fetched as you iterate
3. **Memory Efficient**: Only current page is held in memory
4. **Early Termination**: Break out of loops to stop fetching

### Example: Basic Iteration

```ruby
# No API request yet
enumerator = client.videos

# First API request happens here (fetches page 1)
enumerator.each do |video|
  puts video.id
  # Subsequent pages fetched automatically as needed
end
```

### Example: Getting First N Items

```ruby
# Only fetches enough pages to get 20 videos
recent_videos = client.videos.first(20)

# If page size is 10, this makes 2 API requests
# If page size is 20, this makes 1 API request
# If page size is 50, this makes 1 API request
```

### Example: Early Termination

```ruby
# Stops fetching once condition is met
client.videos.each do |video|
  if video.metadata[:labels][:target] == true
    puts "Found target: #{video.id}"
    break  # No more API requests
  end
end
```

### Performance Considerations

The enumerator supports Ruby Enumerable methods, but be careful with operations that fetch all pages:

**Efficient** (only fetches necessary pages):
```ruby
# Get first N videos
client.videos.first(20)

# Iterate with early break
client.videos.each { |v| break if condition }
```

**Inefficient** (fetches all pages - use with caution):
```ruby
client.videos.to_a      # Fetches ALL pages into array
client.videos.count     # Fetches ALL pages to count
client.videos.map(&:id) # Fetches ALL pages
```

**Important**: The API only supports lookup by ID. There is no API-level filtering by labels or other attributes. If you need to work with specific videos, fetch them by ID directly.

### Pagination Parameters

```ruby
# Control page size
client = PugClient::Client.new(
  namespace: 'my-namespace',
  per_page: 50  # Fetch 50 items per page
)

# Or per-call
videos = client.videos(per_page: 100).first(200)  # Makes 2 requests of 100 each
```

## Automatic Authentication

The client automatically handles OAuth token management, including authentication and refresh.

### How It Works

1. **Initial Authentication**: Call `client.authenticate!` to get an access token
2. **Token Storage**: Token and expiration time are stored in the client instance
3. **Auto-Refresh**: Before every API request, the client checks if the token is expired
4. **Transparent Renewal**: If expired, the client automatically gets a new token

### Implementation

```ruby
# Every API request calls this internally:
def request(method, url, options = {})
  ensure_authenticated!  # <-- Automatic check and refresh
  make_request(method, url, options)
end

def ensure_authenticated!
  authenticate! if !authenticated? || token_expired?
end
```

### User Experience

You don't need to manually refresh tokens:

```ruby
client = PugClient::Client.new(namespace: 'my-namespace')
client.authenticate!  # Initial authentication

# Make requests
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Wait a long time (token expires)
sleep 7200  # 2 hours

# Token is automatically refreshed before this request
video.reload  # Works seamlessly

# You can check token status if needed
puts client.authenticated?  # => true
puts client.token_expired?  # => false (just refreshed)
```

### Manual Token Management

While automatic refresh handles most cases, you can manually manage tokens:

```ruby
# Check authentication status
client.authenticated?  # => true/false

# Check if token is expired
client.token_expired?  # => true/false

# Manually refresh (usually not needed)
client.authenticate!

# Ensure authenticated before a batch operation
client.ensure_authenticated!
```

## Error Handling

The client provides a comprehensive error hierarchy for graceful error handling.

### Error Class Hierarchy

```
PugClient::Error (base class)
├── AuthenticationError - OAuth authentication failed
├── ResourceNotFound - Resource doesn't exist (404)
├── ValidationError - Invalid data or modifications (422)
├── NetworkError - HTTP/network failures
├── TimeoutError - Wait operations exceeded timeout
├── ResourceFrozenError - Attempted to modify frozen/deleted resource
└── FeatureNotSupportedError - Intentionally unsupported endpoints
```

### AuthenticationError

Raised when OAuth authentication fails:

```ruby
begin
  client = PugClient::Client.new(
    namespace: 'my-namespace',
    client_id: 'invalid',
    client_secret: 'invalid'
  )
  client.authenticate!
rescue PugClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
  # Check your credentials
end
```

### ResourceNotFound

Raised when a resource doesn't exist (404 response):

```ruby
begin
  video = client.video('00000000-0000-0000-0000-000000000000')
rescue PugClient::ResourceNotFound => e
  puts "Resource not found: #{e.resource_type} #{e.id}"
  # => "Resource not found: Video non-existent-id"
end
```

### ValidationError

Raised for invalid modifications or input validation failures:

```ruby
# Read-only attribute modification
begin
  video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
  video.id = 'new-id'
rescue PugClient::ValidationError => e
  puts e.message  # => "Cannot modify read-only attribute: id"
end

# Invalid file type
begin
  File.open('video.avi', 'rb') do |file|
    video.upload(file, filename: 'video.avi', content_type: 'video/avi')
  end
rescue PugClient::ValidationError => e
  puts e.message
  # => "Unsupported content type: video/avi. Currently only video/mp4 is supported."
end
```

### NetworkError

Raised for HTTP errors and network failures:

```ruby
begin
  videos = client.videos.first(10)
rescue PugClient::NetworkError => e
  puts "Network error: #{e.message}"
  # Retry logic, circuit breaker, etc.
end
```

### TimeoutError

Raised when wait operations exceed the specified timeout:

```ruby
begin
  video.wait_until_ready(timeout: 60, interval: 5)
rescue PugClient::TimeoutError => e
  puts "Video processing timeout: #{e.message}"
  # => "Video not ready after 60s"

  # Check again later or notify user
end
```

### ResourceFrozenError

Raised when attempting to modify a frozen resource (after deletion):

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
video.delete

# Resource is now frozen
begin
  video.metadata[:labels][:status] = 'deleted'
rescue PugClient::ResourceFrozenError => e
  puts "Cannot modify frozen resource: #{e.message}"
end
```

### FeatureNotSupportedError

Raised for intentionally unsupported endpoints:

```ruby
begin
  # NamespaceClient creation is not supported
  client.create_namespace_client
rescue PugClient::FeatureNotSupportedError => e
  puts e.message
  # Provides explanation and alternatives
end
```

### Error Handling Best Practices

**Catch Specific Errors:**
```ruby
begin
  video = client.video(params[:id])
rescue PugClient::ResourceNotFound
  # Handle 404 specifically
  redirect_to videos_path, alert: 'Video not found'
rescue PugClient::NetworkError
  # Handle network issues
  redirect_to videos_path, alert: 'Service temporarily unavailable'
rescue PugClient::Error => e
  # Catch-all for other Pug errors
  logger.error "Pug API error: #{e.message}"
  redirect_to videos_path, alert: 'An error occurred'
end
```

**Retry on Network Errors:**
```ruby
def fetch_video_with_retry(video_id, retries: 3)
  attempts = 0
  begin
    attempts += 1
    client.video(video_id)
  rescue PugClient::NetworkError => e
    if attempts < retries
      sleep 2 ** attempts  # Exponential backoff
      retry
    else
      raise  # Give up after retries
    end
  end
end
```

## Low-Level HTTP Methods

While all core resources now have dedicated resource classes, the low-level HTTP interface is still available for flexibility and debugging.

### Available Methods

All clients have access to these HTTP methods:

```ruby
# GET request
response = client.get('path/to/resource')

# POST request (with JSON:API formatted body)
response = client.post('path', {
  data: {
    type: 'resource-type',
    attributes: { key: 'value' }
  }
})

# PATCH request (JSON Patch format)
response = client.patch('path', [
  { op: 'replace', path: '/attributes/key', value: 'new-value' }
])

# PUT request
response = client.put('path', { data: {...} })

# DELETE request
client.delete('path')

# Paginated request
results = client.paginate('path', per_page: 50)
```

### When to Use Low-Level Methods

**Use Resource Classes** (preferred):
```ruby
# ✅ Preferred - uses resource class
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
video.metadata[:labels][:status] = 'ready'
video.save
```

**Use Low-Level Methods** (when necessary):
```ruby
# ✅ Acceptable - for debugging or custom endpoints
response = client.get('videos/66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
puts response.inspect

# ✅ Acceptable - for unsupported resources
custom_data = client.get('custom-endpoint')
```

### Response Access

The last response is always available:

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Access last HTTP response
puts client.last_response.status   # => 200
puts client.last_response.headers  # => { 'content-type' => '...', ... }
puts client.last_response.body     # => Raw response body
```

### Example: Custom API Call

```ruby
# Make a custom GET request
response = client.get('namespaces/my-namespace/custom-endpoint', {
  query: { filter: 'value' }
})

puts response.inspect

# Make a custom POST request
response = client.post('namespaces/my-namespace/custom-resource', {
  data: {
    type: 'custom-resources',
    attributes: {
      customField: 'value'
    }
  }
})
```

## Configuration

The client supports multiple configuration methods with a clear precedence hierarchy.

### Configuration Hierarchy (Lowest to Highest Priority)

1. **Environment Defaults** - Production or staging presets
2. **Module-Level Config** - Global configuration via `PugClient.configure`
3. **Instance Options** - Per-client configuration passed to `Client.new`

### Environment Defaults

```ruby
# Production defaults (default)
client = PugClient::Client.new(namespace: 'my-namespace')
# API Endpoint: https://api.video.scorevision.com
# Auth Endpoint: https://fantagio.auth0.com/oauth/token
# Auth Audience: https://api.fantag.io/

# Staging defaults
client = PugClient::Client.new(
  environment: :staging,
  namespace: 'my-namespace'
)
# API Endpoint: https://staging-api.video.scorevision.com
# Auth Endpoint: https://fantagio-staging.auth0.com/oauth/token
# Auth Audience: https://staging-api.fantag.io/
```

### Module-Level Configuration

Global configuration that applies to all clients (unless overridden):

```ruby
PugClient.configure do |config|
  config.environment = :staging
  config.namespace = 'default-namespace'
  config.client_id = ENV['PUG_CLIENT_ID']
  config.client_secret = ENV['PUG_CLIENT_SECRET']
  config.per_page = 25
  config.connection_options = {
    request: {
      open_timeout: 10,
      timeout: 30
    }
  }
end

# All clients inherit these settings
client1 = PugClient::Client.new
client2 = PugClient::Client.new
```

### Instance-Level Configuration

Per-client configuration (highest priority):

```ruby
client = PugClient::Client.new(
  namespace: 'specific-namespace',
  client_id: 'specific-id',
  client_secret: 'specific-secret',
  environment: :staging,
  per_page: 50
)
```

### Complete Configuration Options

```ruby
client = PugClient::Client.new(
  # Required
  namespace: 'my-namespace',

  # Environment preset
  environment: :production,  # or :staging

  # Authentication
  client_id: 'oauth-client-id',
  client_secret: 'oauth-client-secret',
  access_token: 'existing-token',  # Optional: skip auth flow

  # Endpoints (auto-set by environment)
  api_endpoint: 'https://api.video.scorevision.com',
  auth_endpoint: 'https://fantagio.auth0.com/oauth/token',
  auth_audience: 'https://api.fantag.io/',
  auth_grant_type: 'client_credentials',

  # Pagination
  per_page: 10,  # Default page size

  # HTTP configuration
  connection_options: {
    request: {
      open_timeout: 5,   # Connection timeout (seconds)
      timeout: 10        # Read timeout (seconds)
    }
  }
)
```

### Environment Variable Defaults

The gem automatically reads these environment variables:

- `PUG_CLIENT_ID` - OAuth client ID
- `PUG_CLIENT_SECRET` - OAuth client secret
- `PUG_NAMESPACE` - Default namespace

```ruby
# These are equivalent:
client1 = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE'],
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
)

client2 = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE']
)
```

## Module-Level vs Instance-Level API

The client supports two API styles: module-level (singleton) and instance-level.

### Instance-Level API (Recommended)

Most flexible - create multiple clients with different configurations:

```ruby
# Client for namespace A
client_a = PugClient::Client.new(
  namespace: 'namespace-a',
  client_id: 'id-a',
  client_secret: 'secret-a'
)
client_a.authenticate!

videos_a = client_a.videos.first(10)

# Client for namespace B
client_b = PugClient::Client.new(
  namespace: 'namespace-b',
  client_id: 'id-b',
  client_secret: 'secret-b'
)
client_b.authenticate!

videos_b = client_b.videos.first(10)
```

### Module-Level API (Singleton)

Convenient for single-namespace applications:

```ruby
# Configure once
PugClient.configure do |c|
  c.namespace = 'my-namespace'
  c.client_id = ENV['PUG_CLIENT_ID']
  c.client_secret = ENV['PUG_CLIENT_SECRET']
end

# Authenticate once
PugClient.authenticate!

# Use anywhere
namespace = PugClient.namespace
videos = PugClient.videos.first(10)
video = PugClient.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Still works with configured namespace
video.metadata[:labels][:status] = 'ready'
video.save
```

### Module-Level Delegates to Singleton Client

Behind the scenes, module methods delegate to a singleton client:

```ruby
PugClient.configure do |c|
  c.namespace = 'my-namespace'
end

# These are equivalent:
PugClient.videos
PugClient.client.videos

# Singleton client instance:
singleton = PugClient.client
```

### Mixing Both Styles

You can use both simultaneously:

```ruby
# Module-level for default namespace
PugClient.configure do |c|
  c.namespace = 'default-namespace'
end
PugClient.authenticate!

default_videos = PugClient.videos.first(10)

# Instance-level for other namespaces
other_client = PugClient::Client.new(namespace: 'other-namespace')
other_client.authenticate!
other_videos = other_client.videos.first(10)
```

### When to Use Each

**Use Instance-Level When:**
- Multiple namespaces needed
- Per-user/per-tenant isolation required
- Different credentials for different operations
- Testing with multiple configurations

**Use Module-Level When:**
- Single namespace application
- Simpler codebase preferred
- Global singleton pattern fits your architecture

## Related Documentation

- [README.md](../README.md) - Getting started guide
- [RESOURCES.md](RESOURCES.md) - Detailed resource documentation
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata
- [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md) - Rails-specific examples
- [CLAUDE.md](../CLAUDE.md) - Development guide and architecture
- [Pug Video API Documentation](https://api.video.scorevision.com/ui) - Complete API reference
