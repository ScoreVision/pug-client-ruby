# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**pug-client-ruby** is a Ruby gem that provides an object-oriented interface to the Pug Video API. The gem uses a resource-based architecture (recently migrated from client-centric) modeled after Octokit.rb, featuring dirty tracking, automatic JSON Patch generation, and lazy enumeration.

**Key Features:**
- Resource-based OO pattern with smart mutations (automatic dirty tracking + JSON Patch)
- Lazy enumeration via Ruby Enumerator for efficient pagination
- Automatic camelCase ↔ snake_case conversion between API and Ruby code
- Dual API: module-level (singleton) and instance-level configuration
- OAuth2 authentication via Auth0 client credentials flow

**Version:** 0.1.0 (not yet published)
**Ruby:** >= 3.4
**Main Dependencies:** Faraday (>= 2.14)

## Common Commands

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/pug_client/resource_spec.rb

# Run specific test by line number
bundle exec rspec spec/pug_client/resource_spec.rb:42

# Run with documentation format
bundle exec rspec --format documentation

# Run tests matching a pattern
bundle exec rspec --tag focus
```

### Linting
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Check specific files
bundle exec rubocop lib/pug_client/resources/
```

### Documentation
```bash
# Generate YARD documentation
bundle exec yard doc

# View documentation (macOS)
open doc/index.html

# Generate and view in one command
bundle exec rake doc
```

### Other Rake Tasks
```bash
# Run all checks (tests + linting)
bundle exec rake check

# Run tests with coverage
bundle exec rake coverage
```

## Architecture

### High-Level Design

The codebase uses a **mixin composition pattern** centered on the `Client` class:

```
Client
├── includes Configurable    (configuration management)
├── includes Connection       (HTTP via Faraday)
└── includes Authentication   (Auth0 OAuth2)
```

Resources (Namespace, Video, etc.) inherit from `Resource` base class and use:
- `DirtyTracker` - Tracks attribute changes
- `TrackedHash` - Hash subclass that notifies parent resource of mutations
- `AttributeTranslator` - Converts between camelCase (API) and snake_case (Ruby)
- `PatchGenerator` - Converts changes to RFC 6902 JSON Patch operations
- `ResourceEnumerator` - Lazy pagination using Ruby's Enumerator

### Configuration Hierarchy

Configuration precedence (lowest to highest):
1. **Environment defaults** (`DefaultProduction` or `DefaultStaging`)
2. **Module-level config** (`PugClient.configure { }`)
3. **Instance-level options** (passed to `Client.new()`)

**Important distinction:**
- `Client.new(environment: :staging)` → Uses staging defaults, ignores module config
- `Client.new()` → No environment specified, inherits from module-level config

**Required Configuration:**
- `namespace` is REQUIRED during client initialization (raises `ArgumentError` if not provided)
- The namespace serves as the default for all resource operations
- Can be overridden per-call using keyword argument: `client.videos(namespace: 'other-ns')`

### Resource Architecture

All resources follow this pattern:

1. **Base class:** `PugClient::Resource` in `lib/pug_client/resource.rb`
   - Provides attribute storage, dirty tracking, dynamic accessors
   - Defines interface: `save`, `reload`, `delete` (implemented by subclasses)
   - Generates JSON Patch operations from changes

2. **Resource classes:** `lib/pug_client/resources/*.rb`
   - Define `READ_ONLY_ATTRIBUTES` constant
   - Implement class methods: `.find`, `.all`, `.create`, `.from_api_data`
   - Implement instance methods: `#save`, `#reload`, `#delete`
   - Add resource-specific methods (e.g., `video.clip()`, `video.upload()`)

3. **Client integration:** `lib/pug_client/client.rb`
   - Delegates to resource class methods
   - Example: `client.namespace(id)` → `Resources::Namespace.find(self, id)`

### Dirty Tracking Flow

```ruby
# 1. Load resource from API (uses default namespace from client config)
video = client.video('video-123')
# Original attributes stored for comparison

# 2. Mutate nested hash (TrackedHash notifies resource)
video.metadata[:labels][:status] = 'ready'
# Resource marked as dirty

# 3. Generate patch and save
video.save
# Compares original vs current attributes
# Generates JSON Patch: [{op: 'add', path: '/attributes/metadata/labels/status', value: 'ready'}]
# Sends PATCH request to API
# Reloads attributes and clears dirty flag
```

### Lazy Enumeration

Collections return `ResourceEnumerator` which wraps paginated API calls in a Ruby Enumerator:

```ruby
# Fetches pages on-demand during iteration (uses default namespace)
client.videos.each do |video|
  puts video.id
  break if condition  # Stops fetching additional pages
end

# Get first N (only fetches necessary pages)
recent = client.videos.first(10)

# Force eager loading (fetches all pages)
all = client.videos.to_a

# Override namespace for specific call
other_videos = client.videos(namespace: 'other-ns').to_a
```

## File Structure

```
lib/
├── pug_client.rb                      # Main entry point, requires all components
├── pug_client/
│   ├── client.rb                      # Client class (includes mixins, defines resource methods)
│   ├── configurable.rb                # Configuration management
│   ├── connection.rb                  # HTTP layer (Faraday with custom Response wrapper)
│   ├── authentication.rb              # Auth0 OAuth2 flow
│   ├── default.rb                     # Environment defaults (production/staging)
│   ├── version.rb                     # Gem version
│   ├── errors.rb                      # Custom error classes
│   │
│   ├── attribute_translator.rb        # camelCase ↔ snake_case conversion
│   ├── tracked_hash.rb                # Hash that notifies parent of changes
│   ├── dirty_tracker.rb               # Change detection mixin
│   ├── patch_generator.rb             # JSON Patch (RFC 6902) generation
│   ├── resource_enumerator.rb         # Lazy pagination via Enumerator
│   ├── resource.rb                    # Base class for all resources
│   │
│   └── resources/                     # Resource classes (OO API)
│       ├── namespace.rb
│       ├── video.rb
│       ├── live_stream.rb
│       ├── campaign.rb
│       ├── playlist.rb
│       ├── simulcast_target.rb
│       ├── webhook.rb
│       └── namespace_client.rb
│
spec/
├── spec_helper.rb                     # RSpec configuration
├── support/
│   └── vcr.rb                         # VCR configuration for recording API calls
└── pug_client/
    ├── *_spec.rb                      # Unit tests for utilities
    └── resources/
        └── *_spec.rb                  # Tests for resource classes
```

## Intentionally Excluded Endpoints

The following API endpoints exist but are **intentionally NOT implemented** in this Ruby client for security and architectural reasons:

### Excluded Endpoints

1. **Namespace Clients** - `POST /namespaces/:id/clients`
   - Creates namespace-scoped authentication credentials
   - **Why excluded:** Security and credential management concerns
   - **Alternative:** Use web console or contact administrator

2. **Error Reporting** - `POST /namespaces/:id/report/errors`
   - Submits client error reports for monitoring
   - **Why excluded:** Not relevant for server-side Ruby client usage
   - **Alternative:** Use standard Ruby logging and error tracking tools

3. **Event Reporting** - `POST /namespaces/:id/report/events`
   - Tracks user actions and system events for analytics
   - **Why excluded:** Not relevant for server-side Ruby client usage
   - **Alternative:** Use standard Ruby analytics/telemetry tools

4. **Device Initialization** - `POST /namespaces/:id/init`
   - Initializes device metadata and connection context
   - **Why excluded:** Device-specific endpoint, not relevant for server applications
   - **Alternative:** Not applicable for server-side usage

5. **SRS v3 Callbacks** - `POST /srs`
   - Receives HTTP callbacks from Simple Realtime Server for livestream events
   - **Why excluded:** Internal infrastructure endpoint, not for client consumption
   - **Alternative:** Use webhook subscriptions for livestream events

6. **Playlist Listing** - `GET /namespaces/:id/playlists`
   - Lists all playlists within a namespace with pagination
   - **Why excluded:** API does not provide this endpoint (returns 404)
   - **Alternative:** Create and retrieve playlists individually by ID

### Implementation Pattern

When these endpoints are accessed, they raise `FeatureNotSupportedError`:

```ruby
begin
  client.create_namespace_client
rescue PugClient::FeatureNotSupportedError => e
  puts e.message
  # => "Namespace client creation is not supported by this client:
  #     This endpoint is intentionally excluded from the Ruby client.
  #     Please use the web console or contact your administrator to create namespace credentials."
end
```

The excluded resources are retained in the codebase (e.g., `NamespaceClient` class) for documentation purposes, but their methods immediately raise `FeatureNotSupportedError` with helpful error messages.

## Adding New Resources

To add a new resource type (e.g., `Tag`):

### 1. Create Resource Class

Create `lib/pug_client/resources/tag.rb`:

```ruby
module PugClient
  module Resources
    class Tag < Resource
      # Define read-only attributes
      READ_ONLY_ATTRIBUTES = [:id, :created_at, :updated_at].freeze

      attr_reader :namespace_id

      def initialize(client:, namespace_id: nil, attributes: {})
        @namespace_id = namespace_id || attributes[:namespace_id]
        super(client: client, attributes: attributes)
      end

      # Find tag by ID
      def self.find(client, namespace_id, tag_id, options = {})
        response = client.get("namespaces/#{namespace_id}/tags/#{tag_id}", options)
        new(client: client, namespace_id: namespace_id, attributes: response)
      rescue StandardError => e
        raise ResourceNotFound.new('Tag', tag_id) if e.respond_to?(:response) && e.response&.status == 404
        raise NetworkError, e.message
      end

      # List tags (returns lazy enumerator)
      def self.all(client, namespace_id, options = {})
        ResourceEnumerator.new(
          client: client,
          resource_class: self,
          base_url: "namespaces/#{namespace_id}/tags",
          options: options.merge(_namespace_id: namespace_id)
        )
      end

      # Create new tag
      def self.create(client, namespace_id, name, options = {})
        api_attributes = AttributeTranslator.to_api(options.merge(name: name))
        body = { data: { type: 'tags', attributes: api_attributes } }
        response = client.post("namespaces/#{namespace_id}/tags", body)
        new(client: client, namespace_id: namespace_id, attributes: response)
      end

      # Used by ResourceEnumerator
      def self.from_api_data(client, data, options = {})
        namespace_id = options[:_namespace_id]
        new(client: client, namespace_id: namespace_id, attributes: data)
      end

      # Save changes
      def save
        return true unless changed?
        operations = generate_patch_operations
        response = @client.patch("namespaces/#{@namespace_id}/tags/#{id}", operations)
        load_attributes(response)
        clear_dirty!
        true
      end

      # Reload from API
      def reload
        response = @client.get("namespaces/#{@namespace_id}/tags/#{id}")
        load_attributes(response)
        clear_dirty!
        self
      end

      # Delete tag
      def delete
        @client.delete("namespaces/#{@namespace_id}/tags/#{id}")
        freeze_resource!
        true
      end
    end
  end
end
```

### 2. Require in Main File

Add to `lib/pug_client.rb`:

```ruby
require 'pug_client/resources/tag'
```

### 3. Add Client Methods

Add to `lib/pug_client/client.rb`:

```ruby
def tag(tag_id, namespace: @namespace, **options)
  Resources::Tag.find(self, namespace, tag_id, options)
end

def create_tag(name, namespace: @namespace, **options)
  Resources::Tag.create(self, namespace, name, options)
end

def tags(namespace: @namespace, **options)
  Resources::Tag.all(self, namespace, options)
end
```

**Note:** All client resource methods follow this pattern:
- Use `namespace: @namespace` to default to the configured namespace
- Allow per-call override with keyword argument
- Extract additional options with `**options` splat

### 4. Add Namespace Method (if applicable)

If tags belong to namespaces, add to `lib/pug_client/resources/namespace.rb`:

```ruby
def tags(options = {})
  Tag.all(@client, id, options)
end

def create_tag(name, options = {})
  Tag.create(@client, id, name, options)
end
```

### 5. Write Tests

Create `spec/pug_client/resources/tag_spec.rb` following existing patterns. Use VCR to record API interactions.

## Testing Strategy

**Test Stack:** RSpec + VCR + WebMock

**Test Types:**
1. **Unit tests** (`spec/pug_client/`) - Test utilities in isolation (AttributeTranslator, DirtyTracker, etc.)
2. **Resource unit tests** (`spec/pug_client/resources/`) - Test resource behavior with mocked API calls
3. **Integration tests** (`spec/integration/api_v0.3.0/`) - Test full workflows against real API with VCR cassettes

### Integration Tests

Integration tests validate the client against specific API versions by recording real API interactions using VCR. These tests are organized by API version to support testing against multiple versions and to detect breaking changes.

**Directory Structure:**
```
spec/
├── integration/
│   └── api_v0.3.0/           # Tests for API version 0.3.0
│       ├── namespaces_spec.rb
│       ├── videos_spec.rb
│       ├── live_streams_spec.rb
│       ├── campaigns_spec.rb
│       ├── playlists_spec.rb
│       ├── simulcast_targets_spec.rb
│       ├── webhooks_spec.rb
│       └── namespace_clients_spec.rb
└── cassettes/
    └── api_v0.3.0/           # VCR recordings for API 0.3.0
        ├── namespaces/
        ├── videos/
        └── ...
```

**Running Integration Tests:**

```bash
# 1. Load staging credentials
source example/env.sh

# 2. Run all integration tests
bundle exec rspec spec/integration --tag integration

# 3. Run specific resource integration tests
bundle exec rspec spec/integration/api_v0.3.0/videos_spec.rb

# 4. Re-record cassettes (delete old recordings first)
rm -rf spec/cassettes/api_v0.3.0
source example/env.sh
bundle exec rspec spec/integration
```

**VCR Configuration:**
- Cassettes stored in `spec/cassettes/api_v#{version}/` (versioned by API)
- Sensitive data (tokens, secrets) automatically filtered
- Configuration in `spec/support/vcr.rb`
- Integration helper in `spec/support/integration_helper.rb`

**Integration Test Patterns:**

Each resource integration test covers:
- Creating resources
- Finding resources by ID
- Listing resources with pagination
- Updating resources via dirty tracking
- Reloading resources from API
- Deleting resources
- Resource-specific methods (e.g., video.clip, livestream.publish)
- Error scenarios (404, validation errors)

**Example Integration Test:**
```ruby
RSpec.describe 'Videos Integration', :vcr, :integration do
  let(:client) { create_test_client }  # Helper from integration_helper.rb

  it 'creates and updates a video' do
    # VCR records these real API calls
    video = client.create_video(Time.now.utc.iso8601,
      metadata: { labels: { test: 'integration' } }
    )

    video.metadata[:labels][:status] = 'updated'
    expect(video.save).to be true

    # Clean up
    video.delete
  end
end
```

## Key Patterns to Follow

### Attribute Translation
The API uses camelCase, but Ruby uses snake_case:
- `AttributeTranslator.from_api(hash)` - API response → Ruby attributes
- `AttributeTranslator.to_api(hash)` - Ruby attributes → API request

### TrackedHash for Nested Mutations
All Hash values must be wrapped in `TrackedHash` to enable dirty tracking:
```ruby
def wrap_value(value)
  case value
  when Hash
    TrackedHash.new(value, parent_resource: self)
  when Array
    value.map { |v| wrap_value(v) }
  else
    value
  end
end
```

### Read-Only Attributes
Define in each resource class and validate in setters:
```ruby
READ_ONLY_ATTRIBUTES = [:id, :created_at, :duration].freeze

def validate_writable!(attr_name)
  return unless self.class::READ_ONLY_ATTRIBUTES.include?(attr_name)
  raise ValidationError, "Cannot modify read-only attribute: #{attr_name}"
end
```

### JSON:API Format
All API requests/responses use JSON:API format:
```ruby
# Request format
{
  data: {
    type: 'videos',
    attributes: { startedAt: '2025-01-15T10:00:00Z', ... }
  }
}

# Response format (same structure)
```

### Error Handling
Use specific error classes from `lib/pug_client/errors.rb`:
- `ResourceNotFound` - 404 responses
- `ValidationError` - Invalid attribute modifications or input validation
- `NetworkError` - HTTP/network failures
- `TimeoutError` - Wait operations that exceed timeout
- `AuthenticationError` - Auth failures

## Development Workflow

### Working with Staging Environment

```ruby
# Set environment variables
export PUG_CLIENT_ID=your_staging_client_id
export PUG_CLIENT_SECRET=your_staging_client_secret
export PUG_NAMESPACE=your_test_namespace

# Use staging in code (namespace is REQUIRED)
client = PugClient::Client.new(
  environment: :staging,
  namespace: ENV.fetch('PUG_NAMESPACE'),
  client_id: ENV['PUG_CLIENT_ID'],
  client_secret: ENV['PUG_CLIENT_SECRET']
)

# Now use client methods directly
livestreams = client.livestreams.first(10)
video = client.video('video-123')

# Override namespace for specific calls
other_videos = client.videos(namespace: 'other-namespace')
```

### Recording VCR Cassettes

1. Ensure you have valid staging credentials
2. Delete old cassette if updating: `rm spec/cassettes/my_test.yml`
3. Run test with real API calls (VCR records)
4. Commit new cassette to version control
5. Subsequent runs use recorded responses

### Code Style

- Follow RuboCop rules (run `bundle exec rubocop -a` to auto-fix)
- Add YARD documentation to all public methods
- Use `frozen_string_literal: true` pragma
- Prefer explicit returns for public methods
- Keep methods focused and single-purpose

## API Documentation

**OpenAPI Spec:** https://staging-api.video.scorevision.com/openapi.json

**Environments:**
- **Production:** `https://api.video.scorevision.com`
- **Staging:** `https://staging-api.video.scorevision.com`

## Notes

- The gem has completed migration from client-centric to resource-based API
- No backward compatibility concerns (gem not yet published)
- Client class no longer includes legacy client modules (all migrated)
- All API resources now follow the Resource base class pattern
- Examples in `example/` directory show current resource-based usage
