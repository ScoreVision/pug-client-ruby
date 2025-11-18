# Simulcast Targets

Simulcast Targets enable restreaming - broadcasting your livestream to multiple platforms simultaneously (YouTube, Facebook, Twitch, custom RTMP endpoints).

SimulcastTargets are standalone resources that get referenced by livestreams. A single SimulcastTarget can be reused across multiple livestreams.

## Read-Only Attributes

- `id` - SimulcastTarget identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp

## Mutable Attributes

- `url` - Complete RTMP/RTMPS URL including stream key
- `metadata` - Hash with labels and annotations

## Creating Simulcast Targets

SimulcastTargets are created with a complete RTMP URL (including stream key):

```ruby
# Create simulcast targets with complete RTMP URLs
youtube_target = client.create_simulcast_target(
  'rtmp://a.rtmp.youtube.com/live2/your-youtube-stream-key',
  metadata: {
    labels: {
      platform: 'youtube',
      channel: 'eagles-official'
    }
  }
)

facebook_target = client.create_simulcast_target(
  'rtmps://live-api-s.facebook.com:443/rtmp/your-facebook-stream-key',
  metadata: {
    labels: {
      platform: 'facebook',
      page: 'eagles-sports'
    }
  }
)

twitch_target = client.create_simulcast_target(
  'rtmp://live.twitch.tv/app/your-twitch-stream-key',
  metadata: {
    labels: {
      platform: 'twitch',
      channel: 'eagles_gaming'
    }
  }
)

custom_target = client.create_simulcast_target(
  'rtmp://custom.streaming.server/live/custom-stream-key',
  metadata: {
    labels: {
      platform: 'custom',
      provider: 'internal-cdn'
    }
  }
)
```

## Linking Simulcast Targets to Livestreams

There are two workflows for associating simulcast targets with livestreams:

### Workflow 1: Create Targets First, Then Livestream (Recommended)

Create simulcast targets, then create the livestream with references to those targets:

```ruby
# Step 1: Create simulcast targets
youtube = client.create_simulcast_target(
  'rtmp://a.rtmp.youtube.com/live2/stream-key',
  metadata: { labels: { platform: 'youtube' } }
)

facebook = client.create_simulcast_target(
  'rtmps://live-api-s.facebook.com:443/rtmp/stream-key',
  metadata: { labels: { platform: 'facebook' } }
)

# Step 2: Create livestream with simulcast targets
# Can pass SimulcastTarget objects or UUIDs
livestream = client.create_livestream(
  simulcast_targets: [youtube, facebook],  # Accepts objects!
  metadata: {
    labels: {
      event: 'championship-game',
      sport: 'basketball'
    }
  }
)

puts "Livestream #{livestream.id} will simulcast to:"
puts "  YouTube: #{youtube.url}"
puts "  Facebook: #{facebook.url}"
```

### Workflow 2: Create Livestream First, Then Add Targets

Create the livestream, then create and attach simulcast targets:

```ruby
# Step 1: Create livestream
livestream = client.create_livestream(
  metadata: {
    labels: {
      event: 'championship-game',
      sport: 'basketball'
    }
  }
)

# Step 2: Create simulcast targets
youtube = client.create_simulcast_target(
  'rtmp://a.rtmp.youtube.com/live2/stream-key',
  metadata: { labels: { platform: 'youtube' } }
)

twitch = client.create_simulcast_target(
  'rtmp://live.twitch.tv/app/stream-key',
  metadata: { labels: { platform: 'twitch' } }
)

# Step 3: Link targets to livestream
# Accepts SimulcastTarget objects or UUID strings
livestream.simulcast_targets = [youtube, twitch]
livestream.save

puts "Added simulcast targets to livestream #{livestream.id}"
```

### Adding/Removing Targets from Existing Livestream

```ruby
# Get existing livestream
livestream = client.livestream('livestream-id')

# View current simulcast targets (array of UUIDs)
current_targets = livestream.simulcast_targets
# => ["uuid-1", "uuid-2"]

# Create a new target
twitter = client.create_simulcast_target(
  'rtmp://twitter.pscp.tv/x/stream-key',
  metadata: { labels: { platform: 'twitter' } }
)

# Add to existing targets (can mix objects and UUIDs)
livestream.simulcast_targets = current_targets + [twitter]
livestream.save

# Or replace all targets
livestream.simulcast_targets = [twitter]
livestream.save

# Or remove all targets
livestream.simulcast_targets = []
livestream.save
```

## Managing Simulcast Targets

```ruby
# Get a simulcast target
target = client.simulcast_target('863f34e0-6c06-4a76-b162-2787e48af550')

# Update metadata
target.metadata[:labels][:enabled] = false
target.metadata[:labels][:reason] = 'maintenance'
target.save

# Update URL (e.g., new stream key)
target.url = 'rtmp://a.rtmp.youtube.com/live2/new-stream-key'
target.save

# Reload from API
target.reload
```

## Listing Simulcast Targets

```ruby
# List all simulcast targets in namespace
targets = client.simulcast_targets

targets.each do |target|
  puts "Target: #{target.id}"
  puts "  URL: #{target.url}"
  puts "  Platform: #{target.metadata[:labels][:platform]}"
end

# List with pagination
recent_targets = client.simulcast_targets.first(10)

# Filter with metadata
targets.select { |t| t.metadata[:labels][:platform] == 'youtube' }
```

## Deleting Simulcast Targets

```ruby
target = client.simulcast_target('863f34e0-6c06-4a76-b162-2787e48af550')
target.delete
puts "Simulcast target deleted"
```

**Note:** Deleting a simulcast target does NOT automatically remove it from livestreams that reference it. You should update livestreams to remove the deleted target ID.

## Restreaming Use Cases

### Multi-Platform Broadcasting

Stream to YouTube, Facebook, and Twitch simultaneously from a single source:

```ruby
# Create targets for each platform
platforms = {
  youtube: 'rtmp://a.rtmp.youtube.com/live2',
  facebook: 'rtmps://live-api-s.facebook.com:443/rtmp',
  twitch: 'rtmp://live.twitch.tv/app'
}

targets = platforms.map do |platform, server|
  client.create_simulcast_target(
    "#{server}/#{ENV["#{platform.upcase}_STREAM_KEY"]}",
    metadata: { labels: { platform: platform.to_s } }
  )
end

# Create livestream with all targets
livestream = client.create_livestream(
  simulcast_targets: targets,
  metadata: { labels: { event: 'championship-game' } }
)

puts "Livestream will broadcast to #{targets.length} platforms"
```

### Backup Streaming

Simulcast to a backup server for redundancy:

```ruby
primary = client.create_simulcast_target('rtmp://primary.cdn.com/live/key')
backup = client.create_simulcast_target('rtmp://backup.cdn.com/live/key')

livestream = client.create_livestream(
  simulcast_targets: [primary, backup],
  metadata: { labels: { redundancy: 'enabled' } }
)
```

### Internal Distribution

Restream to internal CDN or corporate network for private viewing:

```ruby
internal_cdn = client.create_simulcast_target(
  'rtmp://internal.company.com/live/private-key',
  metadata: { labels: { distribution: 'internal', access: 'private' } }
)
```

### Analytics and Monitoring

Send stream to analytics platform for real-time monitoring:

```ruby
analytics = client.create_simulcast_target(
  'rtmp://analytics.service.com/ingest/key',
  metadata: { labels: { purpose: 'monitoring', provider: 'analytics-co' } }
)
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [LIVESTREAMS.md](LIVESTREAMS.md) - LiveStream documentation
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
