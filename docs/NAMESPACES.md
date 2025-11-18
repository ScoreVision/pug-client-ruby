# Namespaces

Namespaces organize your video content into logical groups. Think of them as projects, folders, or organizational units.

## Overview

- **Required during client initialization** - Serves as default for all operations
- **Scopes access** - All videos, livestreams, etc. belong to a namespace
- **Can be overridden** - Per-call namespace override using `namespace:` parameter

## Read-Only Attributes

- `id` - Namespace identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp

## Finding Namespaces

```ruby
# Get your configured default namespace
namespace = client.namespace
puts namespace.id           # => "my-videos"
puts namespace.created_at   # => 2025-01-15 10:00:00 UTC
puts namespace.metadata     # => { labels: {...}, annotations: {...} }

# Get a specific namespace by ID
other_namespace = client.namespace('acme-corp')
```

## Listing Namespaces

```ruby
# List all namespaces you have access to (lazy iteration)
client.namespaces.each do |ns|
  puts "Namespace: #{ns.id}"
  puts "  Created: #{ns.created_at}"
  puts "  Labels: #{ns.metadata[:labels]}"
end

# Get first N namespaces
recent_namespaces = client.namespaces.first(10)

# List user's namespaces (different endpoint)
user_namespaces = client.user_namespaces.first(10)
```

## Updating Namespace Metadata

```ruby
# Modify metadata with automatic dirty tracking
namespace = client.namespace
namespace.metadata[:labels][:environment] = 'production'
namespace.metadata[:labels][:owner] = 'video-team@example.com'
namespace.metadata[:annotations][:custom_field] = 'value'

# Save sends JSON Patch automatically
namespace.save

# Reload from API (discards unsaved changes)
namespace.reload
```

## Working with Namespace Resources

```ruby
# Get namespace object
namespace = client.namespace

# Access resources through namespace
videos = namespace.videos.first(20)
livestreams = namespace.livestreams.first(10)
campaigns = namespace.campaigns.first(5)

# Create resources through namespace
video = namespace.create_video(Time.now.utc.iso8601)
livestream = namespace.create_livestream('My Stream')
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
- [ADVANCED.md](ADVANCED.md) - Advanced topics and internals
