# API Limitations and Constraints

This document describes the constraints, limitations, and specifications for the Pug Video API.

## Table of Contents

- [Video Processing Limitations](#video-processing-limitations)
- [Metadata Structure](#metadata-structure)
- [Rate Limits](#rate-limits)
- [File Size Limits](#file-size-limits)

## Video Processing Limitations

### Supported Upload Formats

**Currently only MP4 format is supported for video uploads.**

```ruby
# This will work
File.open('video.mp4', 'rb') do |file|
  video.upload(file, filename: 'video.mp4', content_type: 'video/mp4')
end

# This will raise ValidationError
File.open('video.avi', 'rb') do |file|
  video.upload(file, filename: 'video.avi', content_type: 'video/avi')
  # => PugClient::ValidationError: Unsupported content type: video/avi
end
```

### Video Processing Workflow

1. **Upload** - Client uploads MP4 file to cloud storage via signed URL
2. **Backend Transcoding** - Video is processed by backend transcoding pipeline
3. **Renditions Generated** - Multiple quality renditions are created
4. **Ready for Playback** - Video becomes available with playback URLs

```ruby
# Complete workflow
video = client.create_video(Time.now.utc.iso8601)
File.open('game.mp4', 'rb') { |f| video.upload(f, filename: 'game.mp4') }

# Wait for processing to complete
video.wait_until_ready(timeout: 600, interval: 5)

# Access playback URLs once ready
puts video.playback_urls  # => { hls: '...', dash: '...', mp4: '...' }
puts video.renditions     # => Array of quality variants
```

### Output Formats

After processing, videos are available in multiple streaming formats:

- **HLS** (HTTP Live Streaming) - For iOS, Safari, and broad compatibility
- **DASH** (Dynamic Adaptive Streaming over HTTP) - For adaptive bitrate streaming
- **MP4** - Direct progressive download/playback

### Detailed Video Specifications

**Note:** Detailed specifications for the following are managed by the backend transcoding pipeline and are not enforced or validated by this Ruby client:

- Video codecs (H.264, H.265, etc.)
- Audio codecs (AAC, MP3, etc.)
- Resolution constraints (maximum width/height)
- Bitrate specifications
- Frame rate limits
- Quality presets and rendition ladders

**Questions for transcoding pipeline documentation:**
- What video codecs are supported in uploaded MP4 files? (H.264, H.265, etc.)
- What are the minimum and maximum resolutions supported?
- What audio codecs are required/supported?
- What are the maximum file sizes for uploads?
- What rendition qualities are generated? (360p, 480p, 720p, 1080p, 4K?)
- What are the bitrate ranges for each quality level?
- Are there frame rate constraints (e.g., max 60fps)?

For detailed transcoding specifications, consult the Pug Video API backend documentation or the transcoding pipeline configuration.

## Metadata Structure

The Pug API provides two distinct metadata fields with different purposes:

### metadata.labels - User-Defined Categorization

**Purpose:** API consumer use - Categorization, filtering, and user-defined organization

**Structure:** Flat key-value pairs (strings, numbers, booleans)

**Use Cases:** Tagging, filtering, search, custom categorization

**Sports Video Examples:**

```ruby
# Game highlight metadata
video.metadata[:labels] = {
  team: 'eagles',
  opponent: 'patriots',
  game_id: 'game-2025-01-15',
  game_date: '2025-01-15',
  season: '2025',
  sport: 'football',
  league: 'nfl'
}

# Player highlight metadata
video.metadata[:labels] = {
  player_name: 'Tom Brady',
  player_number: '12',
  position: 'QB',
  team: 'patriots',
  highlight_type: 'touchdown',
  quarter: '4',
  play_type: 'pass'
}

# Video management metadata
video.metadata[:labels] = {
  status: 'ready',
  featured: true,
  published: true,
  content_rating: 'family-friendly',
  uploaded_by: 'john@example.com',
  department: 'marketing',
  purpose: 'social-media'
}

# Save changes
video.save
```

**Querying with Labels:**

```ruby
# Filter videos locally by labels
touchdown_videos = client.videos.select do |v|
  v.metadata[:labels][:highlight_type] == 'touchdown'
end

# Or use API filtering (if supported by endpoint)
videos = client.videos(query: { filter: { 'metadata.labels.team': 'eagles' } })
```

### metadata.annotations - System/Backend Metadata

**Purpose:** Backend use - System-generated metadata for internal processing and tracking

**Structure:** Namespaced key-value pairs (typically with domain prefixes like `scorevision.com/`)

**Use Cases:** Command tracking, processing status, system-generated metadata, audit trails

**Common Patterns:**

Annotations are automatically populated by the system when operations are performed. You typically **read** annotations rather than write them.

```ruby
# After running a clip command
clip = video.clip(start_time: 5000, duration: 30000)
puts clip.metadata[:annotations]
# => {
#      "scorevision.com/command": "clip",
#      "scorevision.com/command_source": "a02e3d1c-488f-4455-b1d9-e207b2999b56",
#      "scorevision.com/clip_start_time": "5000",
#      "scorevision.com/clip_duration": "30000"
#    }

# Processing status annotations (set by backend)
video.reload
puts video.metadata[:annotations]
# => {
#      "scorevision.com/processing_status": "completed",
#      "scorevision.com/transcoding_job_id": "job-abc123",
#      "scorevision.com/transcoding_duration_ms": "45230",
#      "scorevision.com/original_filename": "game-footage.mp4"
#    }
```

**Example: Complete Metadata Usage**

```ruby
# Create video with initial labels
video = client.create_video(
  Time.now.utc.iso8601,
  metadata: {
    labels: {
      team: 'eagles',
      game_id: 'game-2025-01-15',
      uploaded_by: 'coach@example.com'
    }
  }
)

# Upload and process
File.open('game.mp4', 'rb') { |f| video.upload(f, filename: 'game.mp4') }
video.wait_until_ready

# Check system annotations (read-only, set by backend)
puts video.metadata[:annotations]['scorevision.com/processing_status']
# => "completed"

# Update user labels
video.metadata[:labels][:reviewed] = true
video.metadata[:labels][:publish_date] = '2025-01-16'
video.save

# Create a clip (annotations automatically added to clip)
highlight = video.clip(
  start_time: 120000,  # 2 minutes in
  duration: 15000,     # 15 second clip
  metadata: {
    labels: {
      highlight_type: 'touchdown',
      quarter: '3',
      team: 'eagles'
    }
  }
)

# Clip has both user labels and system annotations
puts highlight.metadata[:labels][:highlight_type]  # => "touchdown"
puts highlight.metadata[:annotations]['scorevision.com/command']  # => "clip"
```

### Metadata Best Practices

**For labels:**
- Use consistent naming conventions (snake_case recommended)
- Keep values simple (strings, numbers, booleans)
- Think about filtering and search use cases
- Document your label schema for your team
- Consider using enums for status fields (e.g., `status: 'draft'|'ready'|'published'`)

**For annotations:**
- Generally read-only from client perspective
- Use namespaced keys (e.g., `your-company.com/field-name`) if you do write annotations
- Useful for tracking system operations and audit trails
- Check annotations for processing status and error information

## Rate Limits

The Pug Video API implements rate limiting to ensure fair usage and system stability.

**Current Implementation:**
Rate limit details are enforced at the API level. When a rate limit is exceeded, the API will return a `429 Too Many Requests` response.

```ruby
begin
  videos = client.videos.first(100)
rescue PugClient::NetworkError => e
  if e.message.include?('429')
    puts "Rate limit exceeded. Please slow down requests."
    sleep 60  # Wait before retrying
  end
end
```

For specific rate limit thresholds and quotas, please consult the [Pug Video API documentation](https://api.video.scorevision.com/ui).

## File Size Limits

Maximum file sizes for video uploads are enforced by the API and cloud storage layer.

**Recommendations:**
- Test uploads with your typical file sizes
- Implement progress tracking for large uploads
- Consider chunked uploads for very large files (if supported by API)
- Monitor upload timeouts and adjust connection settings accordingly

```ruby
# Increase timeout for large uploads
client = PugClient::Client.new(
  namespace: ENV['PUG_NAMESPACE'],
  connection_options: {
    request: {
      open_timeout: 30,   # Increase connection timeout
      timeout: 300        # Increase read timeout (5 minutes)
    }
  }
)

# Upload with increased timeout
video = client.create_video(Time.now.utc.iso8601)
File.open('large-game-footage.mp4', 'rb') do |file|
  video.upload(file, filename: 'large-game-footage.mp4')
end
```

For specific file size limits, please consult the [Pug Video API documentation](https://api.video.scorevision.com/ui).

## Related Documentation

- [README.md](../README.md) - Getting started guide
- [RESOURCES.md](RESOURCES.md) - Detailed resource documentation
- [ADVANCED.md](ADVANCED.md) - Advanced topics and internals
- [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md) - Rails-specific examples
- [Pug Video API Documentation](https://api.video.scorevision.com/ui) - Complete API reference
