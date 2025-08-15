require 'net/http'
require 'json'

module GeminiProvider
  include AiProviderInterface

  class Client
    include Singleton

    attr_reader :api_key, :base_url

    def initialize
      @api_key = ENV.fetch('GEMINI_API_KEY')
      @base_url = 'https://generativelanguage.googleapis.com'
    end

    def post(endpoint, data)
      http = build_http_connection(endpoint)
      request = build_request(endpoint, data)

      response = http.request(request)
      raise "Gemini API error: #{response.code} - #{response.body}" if response.code.to_i >= 400

      JSON.parse(response.body)
    end

    private

    def build_http_connection(endpoint)
      uri = URI("#{base_url}#{endpoint}?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end

    def build_request(endpoint, data)
      uri = URI("#{base_url}#{endpoint}?key=#{api_key}")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = data.to_json
      request
    end
  end

  class << self
    def embedding(prompt, model = ENV.fetch('GEMINI_EMBEDDING_MODEL', 'embedding-001'))
      # NOTE: Gemini doesn't have a direct embedding API like OpenAI
      # You might need to use a different service for embeddings
      # For now, we'll raise an error
      raise NotImplementedError, "Gemini doesn't support embeddings directly. Use OpenAI or Ollama for embeddings."
    end

    def completion(prompt, model = ENV['GEMINI_LLM'] || 'gemini-2.5-flash')
      Client.instance.post("/v1/models/#{model}:generateContent", {
                             contents: [{
                               parts: [{ text: prompt }]
                             }]
                           })
    end

    def chat(messages, model = ENV['GEMINI_LLM'] || 'gemini-2.5-flash')
      Enumerator.new do |yielder|
        # Convert messages to Gemini format
        gemini_messages = messages.map do |msg|
          { role: msg[:role], parts: [{ text: msg[:content] }] }
        end

        response = Client.instance.post("/v1/models/#{model}:generateContent", {
                                          contents: gemini_messages
                                        })

        yielder << response
      end
    end

    def parse_completion(completion)
      resp = completion.dig('candidates', 0, 'content', 'parts', 0, 'text')
      JSON.parse(resp).with_indifferent_access
    rescue JSON::ParserError
      { content: resp }.with_indifferent_access
    end
  end
end
