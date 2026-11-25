require "webmock/rspec"
require "vcr"

# Specs never reach the network: calls are stubbed with WebMock or replayed from cassettes.
WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.default_cassette_options = { record: :none }

  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
  %w[x-api-key authorization cookie].each do |header|
    config.before_record do |interaction|
      interaction.request.headers.delete_if { |name, _| name.casecmp?(header) }
    end
  end
end
