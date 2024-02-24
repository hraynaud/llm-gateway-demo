require 'ollama-ai'

module OllamaService
  class Client
    include Singleton
    attr_reader :client

    def initialize
      @client = Ollama.new(
        credentials: { address: 'http://localhost:11434' },
        options: { server_sent_events: true }
      )
    end

    def create_embedding(prompt, model = 'nomic-embed-text')
      embeds = client.embeddings(
        { model:, prompt: }
      )
      embeds[0]['embedding']
    end
  end
  class << self
    def create_embedding(prompt)
      client = OllamaService::Client.instance
      client.create_embedding(prompt)
    end
  end
end
