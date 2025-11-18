# Simulcast Targets

Simulcast Targets enable restreaming - broadcasting your livestream to multiple platforms simultaneously (YouTube, Facebook, Twitch, custom RTMP endpoints).

## Read-Only Attributes

- `id` - SimulcastTarget identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp

## Creating a Simulcast Target

```ruby
# Get the livestream
livestream = client.livestream('23b0324a-bc2b-4b7a-a313-1b15af485db6')

# Add YouTube simulcast target
youtube_target = client.create_simulcast_target(
  livestream.id,
  'YouTube Live',
  'rtmp://a.rtmp.youtube.com/live2',
  'your-youtube-stream-key',
  namespace: livestream.namespace_id,
  metadata: {
    labels: {
      platform: 'youtube',
      channel: 'eagles-official',
      enabled: true
    }
  }
)

puts "Created YouTube simulcast: #{youtube_target.id}"

# Add Facebook simulcast target
facebook_target = client.create_simulcast_target(
  livestream.id,
  'Facebook Live',
  'rtmps://live-api-s.facebook.com:443/rtmp/',
  'your-facebook-stream-key',
  namespace: livestream.namespace_id,
  metadata: {
    labels: {
      platform: 'facebook',
      page: 'eagles-sports',
      enabled: true
    }
  }
)

# Add Twitch simulcast target
twitch_target = client.create_simulcast_target(
  livestream.id,
  'Twitch',
  'rtmp://live.twitch.tv/app/',
  'your-twitch-stream-key',
  namespace: livestream.namespace_id,
  metadata: {
    labels: {
      platform: 'twitch',
      channel: 'eagles_gaming',
      enabled: true
    }
  }
)

# Add custom RTMP endpoint
custom_target = client.create_simulcast_target(
  livestream.id,
  'Custom CDN',
  'rtmp://custom.streaming.server/live',
  'custom-stream-key',
  namespace: livestream.namespace_id,
  metadata: {
    labels: {
      platform: 'custom',
      provider: 'internal-cdn',
      enabled: true
    }
  }
)
```

## Managing Simulcast Targets

```ruby
# Get a simulcast target
target = client.simulcast_target('863f34e0-6c06-4a76-b162-2787e48af550')

# Update metadata
target.metadata[:labels][:enabled] = false
target.metadata[:labels][:reason] = 'maintenance'
target.save

# Update target details (if supported)
target.name = 'YouTube Live - Updated'
target.save

# Reload
target.reload
```

## Listing Simulcast Targets

```ruby
# List all simulcast targets for a livestream
livestream = client.livestream('23b0324a-bc2b-4b7a-a313-1b15af485db6')
targets = client.simulcast_targets(livestream.id, namespace: livestream.namespace_id)

targets.each do |target|
  puts "Target: #{target.id}"
  puts "  Name: #{target.name}"
  puts "  Platform: #{target.metadata[:labels][:platform]}"
  puts "  Enabled: #{target.metadata[:labels][:enabled]}"
end
```

## Deleting Simulcast Targets

```ruby
target = client.simulcast_target('863f34e0-6c06-4a76-b162-2787e48af550')
target.delete
puts "Simulcast target deleted"
```

## Restreaming Use Cases

### Multi-Platform Broadcasting

Stream to YouTube, Facebook, and Twitch simultaneously from a single source.

```ruby
livestream = client.create_livestream('Championship Game')

# Add all platforms
%w[youtube facebook twitch].each do |platform|
  client.create_simulcast_target(
    livestream.id,
    "#{platform.capitalize} Live",
    PLATFORM_RTMP_URLS[platform],
    ENV["#{platform.upcase}_STREAM_KEY"],
    namespace: livestream.namespace_id,
    metadata: { labels: { platform: platform, enabled: true } }
  )
end
```

### Backup Streaming

Simulcast to a backup server for redundancy.

### Internal Distribution

Restream to internal CDN or corporate network for private viewing.

### Analytics and Monitoring

Send stream to analytics platform for real-time monitoring.

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [LIVESTREAMS.md](LIVESTREAMS.md) - LiveStream documentation
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
