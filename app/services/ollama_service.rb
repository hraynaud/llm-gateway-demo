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

    def embedding(prompt, model)
      embeds = client.embeddings(
        { model:, prompt: }
      )
      embeds[0]['embedding']
    end

    def completion(prompt, model)
      client.generate(
        { model:, prompt:, stream: false }
      )
    end
  end
  class << self
    def embedding(prompt, model = 'all-minilm')
      Client.instance.embedding(prompt, model)
    end

    def completion(prompt, model = 'llama2')
      Client.instance.completion(prompt, model)
    end
  end
end
