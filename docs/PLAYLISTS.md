# Playlists

Playlists organize videos into ordered collections for sequential playback.

## Read-Only Attributes

- `id` - Playlist identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp
- `version` - Playlist version number
- `playback` - Playback information

## Creating a Playlist

```ruby
playlist = client.create_playlist(
  'Top 10 Touchdowns',
  metadata: {
    labels: {
      category: 'highlights',
      sport: 'football',
      season: '2025',
      curated_by: 'editor@example.com'
    }
  }
)

puts "Created playlist: #{playlist.id}"
```

## Managing Playlists

```ruby
# Get a playlist
playlist = client.playlist('4fb6957c-c4d3-4b67-8d36-18e2c90bfb32')

# Update metadata
playlist.metadata[:labels][:status] = 'published'
playlist.metadata[:labels][:featured] = true
playlist.save

# Reload
playlist.reload
```

## Listing Playlists

**Note:** The Pug API does not provide a dedicated playlist listing endpoint. You must know the playlist ID to retrieve a specific playlist.

```ruby
# Get specific playlist by ID
playlist = client.playlist('4fb6957c-c4d3-4b67-8d36-18e2c90bfb32')

# If you need to list playlists, consider storing playlist IDs
# in your application database or using campaign/namespace metadata
```

## Deleting Playlists

```ruby
playlist = client.playlist('4fb6957c-c4d3-4b67-8d36-18e2c90bfb32')
playlist.delete
puts "Playlist deleted"
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
