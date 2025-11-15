# frozen_string_literal: true

# Shared examples for resources that can be fetched by ID
#
# Usage:
#   RSpec.describe PugClient::Resources::Video do
#     it_behaves_like 'a findable resource', 'videos', :video_id
#   end
#
# Expectations:
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)
#   - ID parameter let block (e.g., :video_id, :webhook_id)
#   - `api_response` let block that returns the full API response

RSpec.shared_examples 'a findable resource' do |resource_type, id_param|
  describe '.find' do
    it 'fetches resource by ID' do
      resource_id = send(id_param)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/#{resource_type}/#{resource_id}", {})
        .and_return(api_response)

      resource = described_class.find(client, namespace_id, resource_id)

      expect(resource).to be_a(described_class)
      expect(resource.id).to eq(resource_id)
      expect(resource.namespace_id).to eq(namespace_id)
    end

    it 'raises ResourceNotFound when resource does not exist' do
      resource_id = send(id_param)

      stub_404_error(client, :get, "namespaces/#{namespace_id}/#{resource_type}/#{resource_id}")

      expect do
        described_class.find(client, namespace_id, resource_id)
      end.to raise_error(PugClient::ResourceNotFound)
    end

    it 'raises NetworkError for other API failures' do
      resource_id = send(id_param)

      stub_network_error(client, :get, "namespaces/#{namespace_id}/#{resource_type}/#{resource_id}",
                         message: 'Connection timeout')

      expect do
        described_class.find(client, namespace_id, resource_id)
      end.to raise_error(PugClient::NetworkError, /Connection timeout/)
    end
  end
end
