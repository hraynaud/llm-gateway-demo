# Added 2026: shared helpers for the bin/ demo scripts. Error handling lives
# here so the original services stay unchanged.
module Demo
  module CLI
    KEYS = { 'openai' => 'OPENAI_API_KEY', 'gemini' => 'GEMINI_API_KEY' }.freeze

    module_function

    def missing_key_message(provider, env = ENV)
      key = KEYS[provider]
      return unless key && env[key].to_s.empty?

      "AI_PROVIDER=#{provider} needs #{key}. Export it, or unset AI_PROVIDER to use local Ollama."
    end

    def search_unsupported_message(provider)
      return unless provider == 'gemini'

      'bin/search needs embeddings, which Gemini does not support here; use AI_PROVIDER=ollama or openai.'
    end

    def error_message(error)
      case error
      when Ollama::Errors::RequestError
        if model_missing?(error)
          "Ollama doesn't have the model. Run: ollama pull #{OllamaService::LLM} " \
            "(and ollama pull #{OllamaService::EMBEDDING_MODEL} for bin/search)."
        elsif unreachable?(error)
          "Can't reach Ollama at #{OllamaService::OLLAMA_SERVER_ADDRESS}. " \
            "Run 'ollama serve', or set AI_PROVIDER=gemini|openai with a key."
        else
          http_error_message(error)
        end
      when NotImplementedError
        error.message
      else
        "#{error.class}: #{error.message}"
      end
    end

    def extract_tagged_json(text, tag)
      block = text[%r{<#{tag}>(.*?)</#{tag}>}m, 1]
      return unless block

      JSON.parse(block)
    rescue JSON::ParserError
      :invalid
    end

    def embedding_model(provider)
      provider == 'openai' ? ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small') : OllamaService::EMBEDDING_MODEL
    end

    def run
      if (message = missing_key_message(AiService.current_provider))
        warn message
        exit 1
      end
      yield
    rescue Interrupt
      puts
    rescue StandardError, NotImplementedError => e
      warn error_message(e)
      exit 1
    end

    def unreachable?(error)
      error.request.is_a?(Faraday::ConnectionFailed) || error.request.is_a?(Faraday::TimeoutError)
    end

    def http_error_message(error)
      cause = error.request
      status = cause.respond_to?(:response_status) ? cause.response_status : nil
      body = cause.respond_to?(:response_body) ? cause.response_body.to_s : ''
      detail = body.empty? ? error.message : body
      "Ollama returned HTTP #{status || 'error'}: #{detail}"
    end

    def model_missing?(error)
      error.request.respond_to?(:response_status) && error.request.response_status == 404
    end
  end
end
