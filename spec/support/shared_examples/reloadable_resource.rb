# frozen_string_literal: true

# Shared examples for resources that can be reloaded from the API
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
#     it_behaves_like 'a reloadable resource', 'videos', :video_id do
#       let(:updated_response) do
#         api_response.dup.tap do |resp|
#           resp[:data][:attributes]['someField'] = 'updated_value'
#         end
#       end
#     end
#   end
#
# Expectations:
#   - `resource_instance` let block defined
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)
#   - ID parameter let block (e.g., :video_id, :webhook_id)
#   - `updated_response` let block with modified API response

RSpec.shared_examples 'a reloadable resource' do |resource_type, id_param|
  describe '#reload' do
    it 'reloads resource from API' do
      resource_id = send(id_param)

      expect(client).to receive(:get)
        .with("namespaces/#{namespace_id}/#{resource_type}/#{resource_id}")
        .and_return(updated_response)

      result = resource_instance.reload

      expect(result).to eq(resource_instance)
      expect(resource_instance.changed?).to be false
    end

    it 'raises NetworkError on API failure' do
      stub_network_error(client, :get, message: 'Connection error')

      expect do
        resource_instance.reload
      end.to raise_error(PugClient::NetworkError, /Connection error/)
    end
  end
end
