# frozen_string_literal: true

require 'pug_client'
require 'rspec'
require 'webmock/rspec'
require 'vcr'

# Load support files
require_relative 'support/vcr'
require_relative 'support/resource_spec_helpers'
require_relative 'support/api_response_helpers'
require_relative 'support/error_stub_helpers'
require_relative 'support/integration_helper'

# Load shared examples
require_relative 'support/shared_examples/findable_resource'
require_relative 'support/shared_examples/listable_resource'
require_relative 'support/shared_examples/saveable_resource'
require_relative 'support/shared_examples/reloadable_resource'
require_relative 'support/shared_examples/deletable_resource'
require_relative 'support/shared_examples/namespace_association'
require_relative 'support/shared_examples/dirty_tracking'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset PugClient configuration before each test
  config.before(:each) do
    PugClient.reset!
  end

  # WebMock configuration
  WebMock.disable_net_connect!(allow_localhost: true)
end
