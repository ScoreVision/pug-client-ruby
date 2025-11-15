# frozen_string_literal: true

# Shared examples for resources with dirty tracking
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
#     it_behaves_like 'has dirty tracking' do
#       let(:mutation) { -> { resource_instance.metadata[:labels][:status] = 'updated' } }
#     end
#   end
#
# Expectations:
#   - `resource_instance` let block defined
#   - `mutation` let block that performs a change

RSpec.shared_examples 'has dirty tracking' do
  describe 'dirty tracking' do
    it 'tracks changes to metadata' do
      expect(resource_instance.changed?).to be false

      mutation.call

      expect(resource_instance.changed?).to be true
      expect(resource_instance.changes).not_to be_empty
    end
  end
end
