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
livestream = client.livestream('livestream-123')

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

LiveStreams support simulcasting - streaming to multiple platforms simultaneously. See the [Simulcast Targets](SIMULCAST_TARGETS.md) documentation for detailed information.

```ruby
# Get livestream
livestream = client.livestream('livestream-123')

# Add simulcast target (YouTube, Facebook, Twitch, custom RTMP)
target = client.create_simulcast_target(
  livestream.id,
  'YouTube',
  'rtmp://a.rtmp.youtube.com/live2',
  'your-stream-key-here',
  namespace: livestream.namespace_id
)

puts "Added simulcast target: #{target.id}"
```

## Deleting LiveStreams

```ruby
livestream = client.livestream('livestream-123')
livestream.delete
puts "LiveStream deleted"
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [SIMULCAST_TARGETS.md](SIMULCAST_TARGETS.md) - Detailed simulcasting guide
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
