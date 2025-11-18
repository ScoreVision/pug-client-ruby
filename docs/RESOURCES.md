# Resources Guide

This document provides an overview and links to detailed documentation for each resource type in the Pug Video API.

## Available Resources

- [Namespaces](NAMESPACES.md) - Organize content into logical groups
- [Videos](VIDEOS.md) - Upload, process, clip, and playback videos
- [LiveStreams](LIVESTREAMS.md) - Real-time video streaming
- [Campaigns](CAMPAIGNS.md) - Ad campaigns with pre-roll/post-roll videos
- [Playlists](PLAYLISTS.md) - Ordered collections of videos
- [Webhooks](WEBHOOKS.md) - Real-time event notifications
- [Simulcast Targets](SIMULCAST_TARGETS.md) - Multi-platform streaming

## Overview

All resources in the Pug API follow a consistent pattern:

- **Resource-based design** - Resources are first-class Ruby objects
- **Automatic dirty tracking** - Changes tracked and converted to JSON Patch operations
- **Lazy enumeration** - Efficient pagination for collections
- **Idiomatic Ruby** - snake_case attributes, natural mutations
- **Default namespace** - Operations use configured namespace unless overridden

## Common Patterns

```ruby
# Initialize client with default namespace
client = PugClient::Client.new(namespace: 'my-videos')
client.authenticate!

# Find a resource by ID (uses default namespace)
resource = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Override namespace for specific call
resource = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5', namespace: 'other-namespace')

# Update attributes with dirty tracking
resource.metadata[:labels][:status] = 'ready'
resource.save  # Auto-generates JSON Patch

# Reload from API
resource.reload

# Delete resource
resource.delete

# List resources lazily (uses default namespace)
client.videos.each { |v| puts v.id }

# Get first N resources efficiently
client.videos.first(20)
```

## Resource Documentation

Click on any resource above to view detailed documentation with examples.

## Additional Documentation

- [README.md](../README.md) - Getting started guide
- [VIDEO_PROCESSING.md](VIDEO_PROCESSING.md) - Complete video format and transcoding specifications
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
- [ADVANCED.md](ADVANCED.md) - Advanced topics and internals
- [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md) - Rails-specific examples
- [Pug Video API Documentation](https://api.video.scorevision.com/ui) - Complete API reference
