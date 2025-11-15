# frozen_string_literal: true

# Shared examples for resources that can be deleted
#
# Usage:
#   RSpec.describe PugClient::Resources::Video do
#     let(:resource_instance) do
#       described_class.new(
#         client: client,
#         namespace_id: namespace_id,
#         attributes: api_response
#       )
#     end
#
#     it_behaves_like 'a deletable resource', 'videos', :video_id
#   end
#
# Expectations:
#   - `resource_instance` let block defined
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)
#   - ID parameter let block (e.g., :video_id, :webhook_id)

RSpec.shared_examples 'a deletable resource' do |resource_type, id_param|
  describe '#delete' do
    it 'deletes the resource' do
      resource_id = send(id_param)

      expect(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/#{resource_type}/#{resource_id}")

      expect(resource_instance.delete).to be true
      expect(resource_instance).to be_frozen
    end

    it 'prevents modifications after deletion' do
      resource_id = send(id_param)

      allow(client).to receive(:delete)
        .with("namespaces/#{namespace_id}/#{resource_type}/#{resource_id}")

      resource_instance.delete

      expect do
        resource_instance.metadata = { test: 'value' }
      end.to raise_error(PugClient::ResourceFrozenError)
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :delete, message: 'Delete failed')

      expect do
        resource_instance.delete
      end.to raise_error(PugClient::NetworkError, /Delete failed/)
    end
  end
end
