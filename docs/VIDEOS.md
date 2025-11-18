# Videos

Videos are the core resource in the Pug API. Each video can be uploaded, processed, clipped, and played back in multiple formats.

## Read-Only Attributes

These attributes are set by the API and cannot be modified:

- `id` - Video identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp
- `duration` - Video duration in milliseconds (available after processing)
- `started_at` - Video start time (timestamp)
- `renditions` - Array of available quality renditions (populated after processing)
- `playback_urls` - URLs for HLS, DASH, and MP4 playback
- `thumbnail_url` - Generated thumbnail URL
- `playback` - Playback information object
- `source` - Source video information

## API Query Limitations

**Important:** The Pug Video API only supports fetching videos by their unique ID. There is no API-level filtering by labels, metadata, or other attributes.

To work with multiple videos:
- Use pagination with `.each` to iterate efficiently
- Use `.first(N)` to fetch a specific number of videos
- Use `.to_a` to explicitly fetch all videos (warning: may fetch thousands of records)

If you need to find specific videos, you must fetch them by ID directly using `client.video(id)`.

## Uploading Videos

### Supported Formats

The API accepts MP4, MOV, AVI, and WMV formats. The content type is automatically detected from the file extension, making uploads simple and straightforward.

**All formats are automatically transcoded to H.264/AAC 720p30** for optimal playback across all devices.

**For complete technical specifications**, see [VIDEO_PROCESSING.md](VIDEO_PROCESSING.md) including:
- Detailed input/output codec specifications
- Resolution and frame rate handling
- Transcoding pipeline features
- Performance optimization tips

### Upload Examples

```ruby
# Simple upload - content type auto-detected from filename
File.open('game.mp4', 'rb') do |file|
  video.upload(file, filename: 'game.mp4')
end

# Works with all supported formats
File.open('game.mov', 'rb') { |f| video.upload(f, filename: 'game.mov') }
File.open('game.avi', 'rb') { |f| video.upload(f, filename: 'game.avi') }
File.open('game.wmv', 'rb') { |f| video.upload(f, filename: 'game.wmv') }

# Override content type if needed (rare)
File.open('video.dat', 'rb') do |file|
  video.upload(file, filename: 'video.dat', content_type: 'video/mp4')
end
```

## Example 1: Create Video + Upload + Get Playback URLs

Complete workflow from creation to playback:

```ruby
# Step 1: Create a video resource
video = client.create_video(
  Time.now.utc.iso8601,  # started_at timestamp (required)
  metadata: {
    labels: {
      title: 'Championship Game Highlights',
      team: 'eagles',
      game_date: '2025-01-15',
      uploaded_by: 'coach@example.com'
    }
  }
)
puts "Created video: #{video.id}"

# Step 2: Upload the video file
File.open('game-highlights.mp4', 'rb') do |file|
  video.upload(file, filename: 'game-highlights.mp4')
end
puts "Upload complete, processing started..."

# Step 3: Wait for transcoding to complete
begin
  video.wait_until_ready(timeout: 600, interval: 5)
  puts "Video processing complete!"
rescue PugClient::TimeoutError => e
  puts "Processing is taking longer than expected: #{e.message}"
end

# Step 4: Access playback information
puts "Playback URLs:"
puts "  HLS: #{video.playback_urls[:hls]}"
puts "  DASH: #{video.playback_urls[:dash]}"
puts "  MP4: #{video.playback_urls[:mp4]}"
puts "Thumbnail: #{video.thumbnail_url}"
puts "Duration: #{video.duration}ms (#{video.duration / 1000}s)"

# Step 5: Verify renditions are available
video.renditions.each do |rendition|
  puts "Rendition: #{rendition}"
end
```

## Example 2: Fetch Video + Modify Metadata + Save

Working with existing videos:

```ruby
# Fetch video by ID
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Check current metadata
puts "Current labels: #{video.metadata[:labels]}"
puts "Current annotations: #{video.metadata[:annotations]}"

# Update metadata labels (user-defined)
video.metadata[:labels][:status] = 'reviewed'
video.metadata[:labels][:reviewed_by] = 'john@example.com'
video.metadata[:labels][:review_date] = Date.today.to_s
video.metadata[:labels][:featured] = true
video.metadata[:labels][:publish_approved] = true

# Add more labels
video.metadata[:labels][:highlight_type] = 'touchdown'
video.metadata[:labels][:quarter] = '4'
video.metadata[:labels][:player_number] = '12'

# Check if changed
if video.changed?
  puts "Video has unsaved changes"

  # Save sends JSON Patch automatically
  video.save
  puts "Changes saved successfully"
end

# Reload from API to get fresh data
video.reload
puts "Reloaded video: #{video.metadata[:labels]}"
```

## Example 3: Iterate Over Videos

Efficient iteration with lazy enumeration:

```ruby
# Iterate with lazy loading (memory efficient)
puts "Recent videos:"
client.videos.first(20).each do |video|
  labels = video.metadata[:labels]
  puts "#{video.id}:"
  puts "  Team: #{labels[:team]}"
  puts "  Game: #{labels[:game_id]}"
  puts "  Duration: #{video.duration}ms" if video.duration
  puts "  Status: #{labels[:status]}"
end

# Get videos from different namespace
other_videos = client.videos(namespace: 'other-namespace').first(10)

# To fetch all videos explicitly (warning: may fetch thousands of records)
all_videos = client.videos.to_a
```

## Example 4: Create Video Clip

The clip command creates a new video from a portion of an existing video:

```ruby
# Get source video
source_video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')
puts "Source duration: #{source_video.duration}ms"

# Create a 30-second clip starting at 2 minutes
clip = source_video.clip(
  start_time: 120000,  # 2 minutes in milliseconds
  duration: 30000,     # 30 seconds in milliseconds
  metadata: {
    labels: {
      type: 'highlight',
      highlight_type: 'touchdown',
      team: 'eagles',
      quarter: '3',
      created_from: source_video.id
    }
  }
)

puts "Created clip: #{clip.id}"

# Clip is a full video resource with system annotations
puts "Clip annotations: #{clip.metadata[:annotations]}"
# => {
#      "scorevision.com/command": "clip",
#      "scorevision.com/command_source": "video-123",
#      ...
#    }

# Wait for clip processing
clip.wait_until_ready(timeout: 300)
puts "Clip ready: #{clip.playback_urls}"

# Update clip metadata
clip.metadata[:labels][:published] = true
clip.save
```

**Note:** Currently, `clip` is the only video command available in the API.

## Getting Video Playback Information

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Wait until ready if recently uploaded
video.wait_until_ready

# Access playback URLs
puts "HLS URL: #{video.playback_urls[:hls]}"
puts "DASH URL: #{video.playback_urls[:dash]}"
puts "MP4 URL: #{video.playback_urls[:mp4]}"

# Access thumbnail
puts "Thumbnail: #{video.thumbnail_url}"

# Check available renditions
video.renditions.each do |rendition|
  puts "Rendition: #{rendition.inspect}"
end

# Get playback object with full details
puts video.playback.inspect
```

## Deleting Videos

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Delete the video
video.delete
puts "Video deleted"

# After deletion, the resource is frozen
begin
  video.metadata[:labels][:status] = 'deleted'
rescue PugClient::ResourceFrozenError => e
  puts "Cannot modify deleted resource: #{e.message}"
end
```

## Accessing Parent Namespace

```ruby
video = client.video('66eb0905-e5e3-4f01-9adf-0a57ce92edc5')

# Get the namespace this video belongs to
namespace = video.namespace
puts "Video belongs to namespace: #{namespace.id}"
```

## Related Documentation

- [VIDEO_PROCESSING.md](VIDEO_PROCESSING.md) - Complete video format and transcoding specifications
- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
- [ADVANCED.md](ADVANCED.md) - Advanced topics and internals
