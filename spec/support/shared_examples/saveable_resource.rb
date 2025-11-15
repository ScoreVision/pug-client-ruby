# frozen_string_literal: true

# Shared examples for resources that can be saved with dirty tracking
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
#     it_behaves_like 'a saveable resource', 'videos', :video_id do
#       let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'updated' } }
#       let(:expected_patch) do
#         [{
#           op: 'add',
#           path: '/metadata/labels/status',
#           value: 'updated'
#         }]
#       end
#     end
#   end
#
# Expectations:
#   - `resource_instance` let block defined
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)
#   - ID parameter let block (e.g., :video_id, :webhook_id)
#   - `api_response` let block for stubbing API response
#   - `mutation` let block that mutates the resource
#   - `expected_patch` let block with expected JSON Patch operations

RSpec.shared_examples 'a saveable resource' do |resource_type, id_param|
  describe '#save' do
    it 'returns true when no changes' do
      expect(client).not_to receive(:patch)
      expect(resource_instance.save).to be true
    end

    it 'sends JSON Patch operations for changes' do
      resource_id = send(id_param)
      mutation.call

      expect(client).to receive(:patch)
        .with("namespaces/#{namespace_id}/#{resource_type}/#{resource_id}", { data: expected_patch })
        .and_return(api_response)

      result = resource_instance.save

      expect(result).to be true
      expect(resource_instance.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      resource_id = send(id_param)
      mutation.call

      stub_network_error(client, :patch, "namespaces/#{namespace_id}/#{resource_type}/#{resource_id}",
                         message: 'API error')

      expect do
        resource_instance.save
      end.to raise_error(PugClient::NetworkError, /API error/)
    end
  end
end
