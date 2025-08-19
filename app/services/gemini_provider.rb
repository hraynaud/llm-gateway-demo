require 'net/http'
require 'json'

module GeminiProvider
  class Client
    include Singleton
    attr_reader :api_key, :base_url, :api_url

    def initialize
      @api_key = ENV.fetch('GEMINI_API_KEY')
      @base_url = 'https://generativelanguage.googleapis.com'
      @model = ENV['GEMINI_LLM'] || 'gemini-2.5-flash'
      @api_url = "/v1beta/models/#{@model}:generateContent"
    end

    def post(data)
      http = build_http_connection
      request = build_request(data)
      response = http.request(request)
      raise "Gemini API error: #{response.code} - #{response.body}" if response.code.to_i >= 400

      JSON.parse(response.body)
    end

    private

    def uri
      URI("#{base_url}#{api_url}?key=#{api_key}")
    end

    def build_http_connection
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end

    def build_request(data)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = data.to_json
      request
    end
  end

  class Bot
    class << self
      def chat(messages, system_instruction = nil)
        # Remove any system messages from the contents since we'll use systemInstruction
        contents = messages.reject { |msg| msg[:role] == 'system' }
                           .map { |msg| { role: msg[:role], parts: [{ text: msg[:content] }] } }

        # Build the request payload
        request_data = {
          contents: contents
        }

        # Add system instruction in the correct format
        if system_instruction
          request_data[:system_instruction] = {
            parts: [{ text: system_instruction }]
          }
        end

        response = Client.instance.post(request_data)

        # Return as enumerator for consistency with other providers
        Enumerator.new do |yielder|
          yielder << response
        end
      end

      def completion(prompt)
        model = ENV['GEMINI_LLM'] || 'gemini-2.5-flash'
        url = api_url(model)
        Client.instance.post(url, {
                               contents: [{
                                 parts: [{ text: prompt }]
                               }]
                             })
      end

      def parse_completion(completion)
        resp = completion.dig('candidates', 0, 'content', 'parts', 0, 'text')
        JSON.parse(resp).with_indifferent_access
      rescue JSON::ParserError
        { content: resp }.with_indifferent_access
      end
    end
  end

  class << self
    def bot
      Bot
    end
  end
end
