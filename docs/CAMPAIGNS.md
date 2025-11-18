# Campaigns

Campaigns group related content together for organization and distribution.

## Read-Only Attributes

- `id` - Campaign identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp
- `version` - Campaign version number

## Creating a Campaign

```ruby
campaign = client.create_campaign(
  'Super Bowl 2025 Highlights',
  metadata: {
    labels: {
      season: '2025',
      sport: 'football',
      event_type: 'championship',
      start_date: '2025-01-15',
      end_date: '2025-02-15'
    }
  }
)

puts "Created campaign: #{campaign.id}"
```

## Managing Campaigns

```ruby
# Get a campaign
campaign = client.campaign('summer-2024-campaign')

# Update metadata
campaign.metadata[:labels][:status] = 'active'
campaign.metadata[:labels][:video_count] = '25'
campaign.save

# Reload
campaign.reload
```

## Listing Campaigns

```ruby
# List all campaigns
client.campaigns.each do |campaign|
  puts "Campaign: #{campaign.id}"
  puts "  Labels: #{campaign.metadata[:labels]}"
  puts "  Version: #{campaign.version}"
end

# Get recent campaigns
recent_campaigns = client.campaigns.first(10)
```

## Deleting Campaigns

```ruby
campaign = client.campaign('summer-2024-campaign')
campaign.delete
puts "Campaign deleted"
```

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
