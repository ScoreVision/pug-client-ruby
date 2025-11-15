# frozen_string_literal: true

# Shared examples for resources that belong to a namespace
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
#     it_behaves_like 'has namespace association'
#   end
#
# Expectations:
#   - `resource_instance` let block defined
#   - `client` let block defined (from shared context)
#   - `namespace_id` let block defined (from shared context)

RSpec.shared_examples 'has namespace association' do
  describe '#namespace' do
    it 'fetches the parent namespace' do
      namespace = instance_double(PugClient::Resources::Namespace, id: namespace_id)

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .and_return(namespace)

      expect(resource_instance.namespace).to eq(namespace)
    end

    it 'caches the namespace' do
      namespace = instance_double(PugClient::Resources::Namespace, id: namespace_id)

      expect(PugClient::Resources::Namespace).to receive(:find)
        .with(client, namespace_id)
        .once
        .and_return(namespace)

      resource_instance.namespace
      resource_instance.namespace # Second call should use cached value
    end
  end
end
