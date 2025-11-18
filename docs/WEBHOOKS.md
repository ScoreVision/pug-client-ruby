# Webhooks

Webhooks enable real-time notifications when events occur in your namespace.

## Read-Only Attributes

- `id` - Webhook identifier
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp

## Creating a Webhook

```ruby
webhook = client.create_webhook(
  'https://example.com/webhooks/pug',
  events: ['video.ready', 'video.failed', 'livestream.started'],
  metadata: {
    labels: {
      environment: 'production',
      application: 'video-platform',
      owner: 'engineering@example.com'
    }
  }
)

puts "Created webhook: #{webhook.id}"
puts "URL: #{webhook.url}"
puts "Events: #{webhook.events.join(', ')}"
```

## Managing Webhooks

```ruby
# Get a webhook
webhook = client.webhook('webhook-123')

# Update webhook URL or events
webhook.url = 'https://example.com/webhooks/pug-v2'
webhook.events = ['video.ready', 'livestream.ended']
webhook.save

# Update metadata
webhook.metadata[:labels][:status] = 'active'
webhook.save

# Reload
webhook.reload
```

## Listing Webhooks

```ruby
# List all webhooks
client.webhooks.each do |webhook|
  puts "Webhook: #{webhook.id}"
  puts "  URL: #{webhook.url}"
  puts "  Events: #{webhook.events.join(', ')}"
end

# Get all webhooks
all_webhooks = client.webhooks.first(50)
```

## Deleting Webhooks

```ruby
webhook = client.webhook('webhook-123')
webhook.delete
puts "Webhook deleted"
```

## Available Webhook Events

Common webhook events include:
- `video.ready` - Video processing completed successfully
- `video.failed` - Video processing failed
- `livestream.started` - LiveStream went live
- `livestream.ended` - LiveStream ended
- `livestream.failed` - LiveStream encountered an error

Consult the [Pug Video API documentation](https://api.video.scorevision.com/ui) for the complete list of available events.

## Related Documentation

- [RESOURCES.md](RESOURCES.md) - Overview of all resources
- [API_LIMITATIONS.md](API_LIMITATIONS.md) - API constraints and metadata details
