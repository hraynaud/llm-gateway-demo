require 'net/http'
require 'json'

module OpenaiProvider
  include AiProviderInterface

  class Client
    include Singleton

    attr_reader :api_key, :base_url, :api_url

    def initialize
      @api_key = ENV.fetch('OPENAI_API_KEY')
      @base_url = ENV.fetch('OPENAI_URI_BASE', 'https://api.openai.com/')
      @model = ENV['OPENAI_LLM'] || 'gpt-4o'
      @api_url = "/v1beta/models/#{@model}:generateContent"
    end

    def post(endpoint, data)
      http = build_http_connection(endpoint)
      request = build_request(endpoint, data)
      response = http.request(request)
      raise "OpenAI API error: #{response.code} - #{response.body}" if response.code.to_i >= 400

      JSON.parse(response.body)
    end

    private

    def build_http_connection(endpoint)
      uri = URI("#{base_url}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http
    end

    def build_request(endpoint, data)
      uri = URI("#{base_url}#{endpoint}")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = data.to_json
      request
    end
  end

  class << self
    def embedding(prompt, model = ENV['OPENAI_EMBEDDING_MODEL'] || 'text-embedding-3-small')
      response = Client.instance.post('v1/embeddings', {
                                        model: model,
                                        input: prompt
                                      })
      response.dig('data', 0, 'embedding')
    end

    def completion(prompt, model = ENV['OPENAI_LLM'] || 'gpt-5-mini')
      Client.instance.post('v1/chat/completions', {
                             model: model,
                             messages: [{ role: 'user', content: prompt }]
                           })
    end

    def chat(messages, model = ENV['OPENAI_LLM'] || 'gpt-5-mini')
      Enumerator.new do |yielder|
        # For streaming, we'll use a non-streaming call for simplicity
        # In production, you might want to implement proper streaming
        response = Client.instance.post('v1/chat/completions', {
                                          model: model,
                                          messages: messages
                                        })

        yielder << response
      end
    end

    def parse_completion(completion)
      resp = completion.dig('choices', 0, 'message', 'content')
      JSON.parse(resp).with_indifferent_access
    rescue JSON::ParserError
      { content: resp }.with_indifferent_access
    end
  end
end
