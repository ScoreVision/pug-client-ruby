# frozen_string_literal: true

# Shared contexts and helpers for resource spec tests
#
# This module provides common setup for resource spec tests, reducing duplication
# across test files. It includes shared let blocks for client setup and common
# identifiers.
#
# Usage:
#   RSpec.describe PugClient::Resources::Video do
#     include_context 'resource spec client'
#     # Now you have access to `client` and `namespace_id` let blocks
#   end

RSpec.shared_context 'resource spec client' do
  # Shared client double for unit tests
  # Use instance_double for better type checking
  let(:client) { instance_double(PugClient::Client) }

  # Common namespace identifier used across all namespaced resource tests
  let(:namespace_id) { 'test-namespace' }
end

# No automatic inclusion - specs manually include this context when needed
