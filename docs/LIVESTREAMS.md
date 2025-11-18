# LiveStreams

LiveStreams enable real-time video streaming with support for multiple simultaneous outputs (simulcasting).

## Read-Only Attributes

- `id` - LiveStream identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp
- `started_at` - Stream start time
- `stream_status` - Current streaming status
- `stream_urls` - Ingest URLs for streaming
- `playback_urls` - URLs for viewing the stream
- `thumbnails` - Generated thumbnail URLs

## Creating a LiveStream

```ruby
# Create a livestream
livestream = client.create_livestream(
  'Championship Game Live',
  metadata: {
    labels: {
      event: 'championship-2025',
      team: 'eagles',
      sport: 'football',
      scheduled_start: '2025-01-15T19:00:00Z'
    }
  }
)

puts "Created livestream: #{livestream.id}"
puts "Stream to: #{livestream.stream_urls[:rtmp]}"
puts "Watch at: #{livestream.playback_urls[:hls]}"
```

## Managing LiveStreams

```ruby
# Get a livestream
livestream = client.livestream('23b0324a-bc2b-4b7a-a313-1b15af485db6')

# Check stream status
puts "Status: #{livestream.stream_status}"

# Update metadata
livestream.metadata[:labels][:status] = 'live'
livestream.metadata[:labels][:viewers] = '1500'
livestream.save

# Get stream URLs
puts "RTMP Ingest: #{livestream.stream_urls[:rtmp]}"
puts "Stream Key: #{livestream.stream_urls[:key]}"

# Get playback URLs
puts "HLS Playback: #{livestream.playback_urls[:hls]}"
puts "DASH Playback: #{livestream.playback_urls[:dash]}"

# Reload to get latest status
livestream.reload
```

## Listing LiveStreams

```ruby
# List all livestreams (lazy iteration)
client.livestreams.each do |stream|
  puts "Stream: #{stream.id}"
  puts "  Status: #{stream.stream_status}"
  puts "  Labels: #{stream.metadata[:labels]}"
end

# Get recent livestreams
recent_streams = client.livestreams.first(10)

# Override namespace
other_streams = client.livestreams(namespace: 'other-ns').first(5)
```

## Simulcast Targets (Restreaming)

LiveStreams support simulcasting - streaming to multiple platforms simultaneously.

```ruby
# Create simulcast targets
youtube = client.create_simulcast_target('rtmp://a.rtmp.youtube.com/live2/stream-key')
facebook = client.create_simulcast_target('rtmps://live-api-s.facebook.com:443/rtmp/stream-key')

# Create livestream with simulcast targets
livestream = client.create_livestream(
  simulcast_targets: [youtube, facebook],
  metadata: { labels: { event: 'game' } }
)

# Or add to existing livestream
livestream = client.livestream('livestream-id')
livestream.simulcast_targets = [youtube, facebook]
livestream.save
```

See the [Simulcast Targets](SIMULCAST_TARGETS.md) documentation for complete details on workflows, managing targets, and multi-platform broadcasting.

## Deleting LiveStreams

```ruby
livestream = client.livestream('23b0324a-bc2b-4b7a-a313-1b15af485db6')
livestream.delete
puts "LiveStream deleted"
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [SIMULCAST_TARGETS.md](SIMULCAST_TARGETS.md) - Detailed simulcasting guide
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
