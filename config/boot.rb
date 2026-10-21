# The whole shell: the small slice of Rails that app/services relied on, so the
# original files run unmodified as plain Ruby. Controllers are not loaded.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
require 'json'
require 'logger'
require 'net/http'
require 'singleton'
require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'

unless defined?(Rails)
  module Rails
    def self.logger
      @logger ||= Logger.new(
        $stderr,
        level: ENV.fetch('LOG_LEVEL', 'warn'),
        formatter: proc { |severity, _time, _prog, msg| "[#{severity.downcase}] #{msg}\n" }
      )
    end
  end
end

# The original default is the docker-compose hostname; standalone, Ollama is local.
ENV['OLLAMA_SERVER_ADDRESS'] ||= 'http://localhost:11434'

# Dependency order: providers, the factory, base assistants, subclasses, services.
%w[
  ollama_service openai_provider gemini_provider
  ai_service
  ai_assistant gemini_assistant openai_assistant
  gemini_project_assistant gemini_onboarding_assistant
  openai_project_assistant openai_onboarding_assistant
  chat_service summarizer_service
].each { |file| require_relative "../app/services/#{file}" }
