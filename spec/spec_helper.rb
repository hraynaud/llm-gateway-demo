# Deterministic, offline test environment: default provider, fake keys, no network.
ENV.delete('AI_PROVIDER')
ENV['OPENAI_API_KEY'] ||= 'test-openai-key'
ENV['GEMINI_API_KEY'] ||= 'test-gemini-key'

require_relative '../config/boot'
require 'webmock/rspec'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  config.filter_run_excluding :live unless ENV['LIVE']

  # AiService memoises its provider; reset so switch_provider never leaks between examples.
  config.after { AiService.instance_variable_set(:@provider, nil) }
end
