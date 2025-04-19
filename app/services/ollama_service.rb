require 'ollama-ai'

module OllamaService
  EMBEDDING_MODEL = ENV.fetch('EMBEDDING_MODEL', 'mxbai-embed-large')
  LLM = ENV.fetch('LLM', 'llama3')
  OLLAMA_SERVER_ADDRESS = ENV.fetch('OLLAMA_SERVER_ADDRESS', 'http://ollama:11434')
  class Client
    include Singleton
    attr_reader :client

    def initialize
      @client = Ollama.new(
        credentials: { address: OLLAMA_SERVER_ADDRESS },
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

    def chat(messages, model)
      Enumerator.new do |yielder|
        client.chat({ messages:, model:, stream: true }) do |event|
          yielder << event
        end
      end
    end
  end

  class << self
    def embedding(prompt, model = EMBEDDING_MODEL)
      Client.instance.embedding(prompt, model)
    end

    def completion(prompt, model = LLM)
      Client.instance.completion(prompt, model)
    end

    def chat(messages, model = LLM)
      Client.instance.chat(messages, model)
    end

    def parse_completion(completion)
      resp = completion[0]['response']
      JSON.parse(resp).with_indifferent_access
    end
  end
end
