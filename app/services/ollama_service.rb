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

    def create_embedding(prompt, model = 'llama2')
      embeds = client.embeddings(
        { model:, prompt: }
      )
      embeds[0]['embeddding']
    end
    handle_asynchronously :create_embedding, queue: 'embeddings'
  end
  class << self
    def create_embedding(prompt)
      client = OllamaService::Client.instance
      client.create_embedding(prompt)
    end
  end
end
