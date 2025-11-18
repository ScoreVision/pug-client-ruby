# Video Processing Guide

Complete technical reference for video upload formats, transcoding specifications, and the processing pipeline.

## Table of Contents

- [Supported File Formats](#supported-file-formats)
- [Input Specifications](#input-specifications)
- [Output Specifications](#output-specifications)
- [Transcoding Pipeline](#transcoding-pipeline)
- [Upload Examples](#upload-examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Supported File Formats

The Pug API accepts these video file formats for upload:

| Format | Extension | MIME Type | Description |
|--------|-----------|-----------|-------------|
| MPEG-4 | `.mp4` | `video/mp4` | **Recommended** - Most compatible format |
| QuickTime | `.mov` | `video/quicktime` | Common for Apple/professional video production |
| AVI | `.avi` | `video/x-msvideo` | Legacy Windows format, widely supported |
| Windows Media | `.wmv` | `video/x-ms-wmv` | Windows Media Video format |

**All formats are automatically transcoded** to a standardized output format during processing for optimal playback across all devices and platforms.

## Input Specifications

The transcoding pipeline uses a **permissive validation approach** - it accepts any video format that ffmpeg can decode, with automatic conversion applied during transcoding. There are no explicit validation checks for input codec, resolution, frame rate, or bitrate.

### Video Codecs

- **Accepted:** Any video codec supported by ffmpeg
  - H.264 (AVC)
  - H.265 (HEVC)
  - VP8, VP9
  - MPEG-2, MPEG-4
  - AV1
  - And many others
- **Validation:** None - codec detection and conversion handled automatically by ffmpeg
- **Processing:** All inputs are converted to H.264 Main Profile Level 4.0

### Audio Codecs

- **Accepted:** Any audio codec supported by ffmpeg
  - AAC
  - MP3
  - Vorbis
  - Opus
  - PCM
  - FLAC
  - And many others
- **Validation:** None - codec detection and conversion handled automatically by ffmpeg
- **Processing:** All inputs are converted to AAC 128kbps stereo at 48kHz
- **Audio Sync:** Automatic async resampling enabled to handle A/V synchronization issues

### Resolution

- **Accepted:** Any resolution (no minimum or maximum constraints)
- **Processing:** Output is scaled to 720p height with width auto-calculated to maintain aspect ratio
  - Formula: `scale=-2:720` (width auto-calculated for aspect ratio)
  - Example: 16:9 video → 1280x720
  - Example: 4:3 video → 960x720
- **Note:** Both upscaling (from lower resolutions) and downscaling (from higher resolutions) are applied as needed

### Frame Rate

- **Accepted:** Any frame rate (variable or constant)
- **Processing:** Output is forced to constant 30 fps
- **Note:** Both frame rate increase and decrease are handled automatically

### Interlaced Video

- **Accepted:** Both progressive and interlaced video
- **Processing:** Deinterlacing is automatically applied to all inputs for smooth progressive playback

### Duration

- **Accepted:** No duration limits
- **Validation:** None
- **Note:** Processing time scales linearly with input duration

### File Size

- **Accepted:** No application-level file size limits
- **Validation:** None
- **Note:** Google Cloud Storage bucket quotas and limits apply to uploads

## Output Specifications

All uploaded videos are transcoded to a standardized format for optimal playback compatibility across all devices and platforms.

### Video Output

- **Codec:** H.264 Main Profile Level 4.0
- **Resolution:** 720p height (width auto-calculated to maintain aspect ratio)
  - 16:9 aspect ratio → 1280x720
  - 4:3 aspect ratio → 960x720
  - 21:9 ultrawide → 1920x720
- **Frame Rate:** 30 fps (constant frame rate)
- **Pixel Format:** yuv420p (maximum compatibility across devices)

### Audio Output

- **Codec:** AAC (Advanced Audio Coding)
- **Bitrate:** 128 kbps
- **Channels:** Stereo (2 channels)
- **Sample Rate:** 48 kHz

### Playback Formats

After transcoding, videos are available in multiple streaming formats for maximum compatibility:

- **HLS** (HTTP Live Streaming) - For iOS, Safari, and broad compatibility
- **DASH** (Dynamic Adaptive Streaming) - For adaptive bitrate streaming
- **MP4** (Progressive Download) - For direct download/playback

Access these through the `playback_urls` attribute:

```ruby
video.wait_until_ready
puts video.playback_urls
# => {
#   hls: 'https://cdn.example.com/video.m3u8',
#   dash: 'https://cdn.example.com/video.mpd',
#   mp4: 'https://cdn.example.com/video.mp4'
# }
```

## Transcoding Pipeline

The transcoding pipeline automatically applies these enhancements and conversions to all uploaded videos:

### Automatic Processing Features

**Deinterlacing:**
- Applied unconditionally to all inputs
- Handles interlaced content (typically from older cameras or broadcast sources)
- Ensures smooth progressive playback on modern devices

**Audio Synchronization:**
- Automatic async audio resampling with configuration:
  - `aresample=async=1:min_hard_comp=0.100000:first_pts=0`
- Corrects audio/video synchronization issues
- Prevents lip-sync problems in transcoded output

**Pixel Format Normalization:**
- All inputs converted to yuv420p color space
- Ensures maximum playback compatibility
- Supports widest range of devices and browsers

**Aspect Ratio Preservation:**
- Original aspect ratio is maintained during scaling to 720p
- No distortion or stretching
- Black bars not added - width adjusted to maintain ratio

**Max Muxing Queue Size:**
- Set to 1024 to handle complex input streams
- Prevents buffer overflow with multi-track inputs

### Processing Workflow

1. **Upload** - File uploaded to cloud storage via signed URL
2. **Detection** - ffmpeg automatically detects format, codecs, and characteristics
3. **Transcode** - Video converted to H.264 720p30, audio to AAC 128kbps
4. **Generate Renditions** - Multiple formats created (HLS, DASH, MP4)
5. **Ready** - Video becomes available for playback

Check processing status:

```ruby
# After upload, video is processing
video.upload(file, filename: 'game.mp4')

# Wait for processing to complete
video.wait_until_ready(timeout: 600, interval: 5)

# Check if ready
if video.renditions && !video.renditions.empty?
  puts "Video ready for playback!"
  puts video.playback_urls
end
```

## Upload Examples

### Basic Upload (Auto-Detect Content Type)

The simplest way to upload - content type is automatically detected from the file extension:

```ruby
# MP4 format (recommended)
File.open('game.mp4', 'rb') do |file|
  video.upload(file, filename: 'game.mp4')
end

# QuickTime MOV
File.open('footage.mov', 'rb') do |file|
  video.upload(file, filename: 'footage.mov')
end

# AVI format
File.open('recording.avi', 'rb') do |file|
  video.upload(file, filename: 'recording.avi')
end

# Windows Media
File.open('video.wmv', 'rb') do |file|
  video.upload(file, filename: 'video.wmv')
end
```

### Complete Upload Workflow

```ruby
# Create video resource
video = client.create_video(
  Time.now.utc.iso8601,
  metadata: {
    labels: {
      title: 'Championship Game',
      team: 'eagles',
      game_date: '2025-01-15'
    }
  }
)

# Upload file (content type auto-detected)
File.open('championship.mp4', 'rb') do |file|
  video.upload(file, filename: 'championship.mp4')
end

# Wait for processing (600 second timeout, check every 5 seconds)
begin
  video.wait_until_ready(timeout: 600, interval: 5)
  puts "Video processing complete!"
rescue PugClient::TimeoutError => e
  puts "Processing is taking longer than expected: #{e.message}"
  # Video is still processing - check again later
end

# Access playback information
puts "Duration: #{video.duration}ms"
puts "HLS URL: #{video.playback_urls[:hls]}"
puts "DASH URL: #{video.playback_urls[:dash]}"
puts "MP4 URL: #{video.playback_urls[:mp4]}"
puts "Thumbnail: #{video.thumbnail_url}"

# Check available renditions
video.renditions.each do |rendition|
  puts "Rendition: #{rendition.inspect}"
end
```

### Override Content Type (Advanced)

For files without standard extensions, you can explicitly specify the content type:

```ruby
# File without standard extension
File.open('data.bin', 'rb') do |file|
  video.upload(file, filename: 'data.bin', content_type: 'video/mp4')
end
```

## Best Practices

### Recommended Upload Format

For best results and fastest processing, upload videos that match or exceed the output specifications:

**Optimal Format:**
- **Container:** MP4
- **Video Codec:** H.264
- **Resolution:** 720p or higher (1080p, 4K)
- **Frame Rate:** 30 fps (or 60 fps - will be converted to 30)
- **Audio Codec:** AAC
- **Audio Bitrate:** 128 kbps or higher

```ruby
# Example of optimal upload
# Source: 1080p H.264/AAC MP4 file
File.open('optimal-source.mp4', 'rb') do |file|
  video.upload(file, filename: 'optimal-source.mp4')
end
```

### Performance Tips

**Higher Resolution Sources:**
- Upload 1080p or 4K sources for best 720p output quality
- Downscaling preserves detail better than upscaling
- Modern cameras typically shoot 1080p or higher

**Matching Source Specifications:**
- Videos already in H.264/AAC 720p30 will transcode fastest
- Less conversion = faster processing time

**Legacy Codec Considerations:**
- Older codecs (MPEG-2, older WMV versions) may take longer to transcode
- Consider pre-converting very old formats to H.264/MP4 before upload

**Interlaced Video:**
- Interlaced video (from broadcast sources) adds processing time for deinterlacing
- Modern cameras shoot progressive - preferred when possible

### File Organization

Use descriptive filenames and metadata:

```ruby
video = client.create_video(
  Time.now.utc.iso8601,
  metadata: {
    labels: {
      title: 'Eagles vs Patriots - Q4 Touchdown',
      sport: 'football',
      team: 'eagles',
      opponent: 'patriots',
      event_type: 'touchdown',
      quarter: '4',
      game_date: '2025-01-15',
      player_number: '12',
      duration_sec: (30_000 / 1000).to_s  # If known
    }
  }
)

File.open('eagles-patriots-q4-touchdown.mp4', 'rb') do |file|
  video.upload(file, filename: 'eagles-patriots-q4-touchdown.mp4')
end
```

## Troubleshooting

### Upload Failures

**Problem:** Upload fails with ValidationError

**Solutions:**
- Verify file extension is .mp4, .mov, .avi, or .wmv
- Check that file exists and is readable
- Ensure file is not corrupted

```ruby
begin
  File.open('video.mp4', 'rb') { |f| video.upload(f, filename: 'video.mp4') }
rescue PugClient::ValidationError => e
  puts "Validation error: #{e.message}"
  # Check file extension and format
rescue Errno::ENOENT
  puts "File not found - check path"
end
```

### Processing Timeouts

**Problem:** `wait_until_ready` raises TimeoutError

**Solutions:**
- Increase timeout for large/long videos
- Very large 4K files may take longer to process
- Check video actually uploaded successfully

```ruby
# Increase timeout for large videos
begin
  video.wait_until_ready(timeout: 1200, interval: 10)  # 20 minutes
rescue PugClient::TimeoutError
  # Video is still processing - check status later
  puts "Still processing... checking later"

  # Check again after some time
  sleep 300  # Wait 5 minutes
  video.reload
  if video.renditions && !video.renditions.empty?
    puts "Now ready!"
  end
end
```

### Unsupported Formats

**Problem:** Receiving validation errors for unsupported file types

**Solutions:**
- Convert to MP4 using ffmpeg or video conversion tool
- Use .mp4, .mov, .avi, or .wmv containers
- Verify MIME type matches extension

```bash
# Convert unsupported format to MP4 using ffmpeg
ffmpeg -i input.mkv -c:v libx264 -c:a aac output.mp4
```

### Poor Output Quality

**Problem:** Transcoded video has poor quality

**Solutions:**
- Upload higher resolution source (1080p or 4K)
- Ensure source is not heavily compressed
- Verify source video quality before upload

### Audio Sync Issues

**Problem:** Audio and video out of sync in output

**Note:** The transcoding pipeline includes automatic audio synchronization. If you experience sync issues:
- Verify source file plays correctly before upload
- Report persistent issues - automatic resampling should handle most cases

## Related Documentation

- [README.md](../README.md) - Getting started guide
- [VIDEOS.md](VIDEOS.md) - Video resource documentation and examples
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata
- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [Pug Video API Documentation](https://api.video.scorevision.com/ui) - Complete API reference
