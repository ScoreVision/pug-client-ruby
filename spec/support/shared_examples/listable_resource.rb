# frozen_string_literal: true

# Shared examples for resources that can be listed with pagination
#
# Usage:
#   RSpec.describe PugClient::Resources::Video do
#     it_behaves_like 'a listable resource', 'videos'
#   end
#
# Expectations:
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)

RSpec.shared_examples 'a listable resource' do |resource_type|
  describe '.all' do
    it 'returns a ResourceEnumerator' do
      enumerator = described_class.all(client, namespace_id)

      expect(enumerator).to be_a(PugClient::ResourceEnumerator)
    end

    it 'passes namespace_id in options' do
      expect(PugClient::ResourceEnumerator).to receive(:new).with(
        hash_including(
          client: client,
          base_url: "namespaces/#{namespace_id}/#{resource_type}",
          resource_class: described_class,
          options: hash_including(_namespace_id: namespace_id)
        )
      )

      described_class.all(client, namespace_id)
    end
  end
end
