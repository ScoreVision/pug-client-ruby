# frozen_string_literal: true

# Helpers for simulating API errors in tests
#
# This module provides utility methods to stub common error scenarios
# (404 Not Found, Network Errors, etc.) in a consistent way across tests.
#
# Usage:
#   RSpec.describe SomeSpec do
#     it 'handles 404 errors' do
#       stub_404_error(client, :get, '/videos/missing')
#
#       expect { client.get('/videos/missing') }
#         .to raise_error(PugClient::ResourceNotFound)
#     end
#   end

module ErrorStubHelpers
  # Stub a 404 Not Found error response
  #
  # This creates a properly formatted error that will trigger ResourceNotFound
  # exceptions in the client code.
  #
  # @param client_double [RSpec::Mocks::Double] Client double to stub
  # @param method [Symbol] HTTP method (:get, :post, :patch, :delete, :put)
  # @param endpoint [String] Optional specific endpoint to match
  # @return [void]
  #
  # @example Stub any GET request
  #   stub_404_error(client, :get)
  #
  # @example Stub specific endpoint
  #   stub_404_error(client, :get, 'namespaces/test-ns/videos/missing-id')
  def stub_404_error(client_double, method = :get, endpoint = nil)
    error = StandardError.new('Not Found')
    response = double('Response', status: 404, body: { errors: [{ status: '404' }] })

    # Make error respond to :response with the 404 response
    allow(error).to receive(:respond_to?).and_call_original
    allow(error).to receive(:respond_to?).with(:response).and_return(true)
    allow(error).to receive(:response).and_return(response)

    # Stub the client method to raise the error
    stub = allow(client_double).to receive(method)
    stub = stub.with(endpoint, anything) if endpoint
    stub.and_raise(error)
  end

  # Stub a generic network/API error
  #
  # This simulates general API failures that should trigger NetworkError exceptions.
  #
  # @param client_double [RSpec::Mocks::Double] Client double to stub
  # @param method [Symbol] HTTP method (:get, :post, :patch, :delete, :put)
  # @param endpoint [String] Optional specific endpoint to match
  # @param message [String] Error message (default: 'API Error')
  # @return [void]
  #
  # @example
  #   stub_network_error(client, :post, 'namespaces/test-ns/videos')
  def stub_network_error(client_double, method = :get, endpoint = nil, message: 'API Error')
    error = StandardError.new(message)

    stub = allow(client_double).to receive(method)
    stub = stub.with(endpoint, anything) if endpoint
    stub.and_raise(error)
  end

  # Stub a successful response for create/update operations
  #
  # This is useful for stubbing save operations that don't need specific
  # response data validation.
  #
  # @param client_double [RSpec::Mocks::Double] Client double to stub
  # @param method [Symbol] HTTP method (:post, :patch, :put)
  # @param endpoint [String] Optional specific endpoint
  # @param response_data [Hash] Response to return (default: empty success response)
  # @return [void]
  #
  # @example
  #   stub_successful_response(client, :patch, 'namespaces/test-ns/videos/v123')
  def stub_successful_response(client_double, method, endpoint = nil, response_data: {})
    default_response = { data: { id: 'test-id', type: 'test', attributes: {} } }
    response = response_data.empty? ? default_response : response_data

    stub = allow(client_double).to receive(method)
    stub = stub.with(endpoint, anything) if endpoint
    stub.and_return(response)
  end
end

# Include helpers in all RSpec tests
RSpec.configure do |config|
  config.include ErrorStubHelpers
end
