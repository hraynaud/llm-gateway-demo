module AiService
  class << self
    def provider
      @provider ||= case ENV.fetch('AI_PROVIDER', 'ollama').downcase
                    when 'openai'
                      OpenaiProvider
                    when 'gemini'
                      GeminiProvider
                    else
                      OllamaService # default fallback
                    end
    end

    def embedding(prompt, model = nil)
      if model
        provider.embedding(prompt, model)
      else
        provider.embedding(prompt)
      end
    end

    def project_assistant
      GeminiProjectAssistant.new
    end

    def completion(prompt, model = nil)
      if model
        provider.completion(prompt, model)
      else
        provider.completion(prompt) # Let provider use its default
      end
    end

    def chat(messages, model = nil)
      if model
        provider.chat(messages, model)
      else
        provider.chat(messages)
      end
    end

    def parse_completion(completion)
      provider.parse_completion(completion)
    end

    # Method to dynamically switch providers
    def switch_provider(provider_name)
      @provider = case provider_name.downcase
                  when 'openai'
                    OpenaiProvider
                  when 'gemini'
                    GeminiProvider
                  when 'ollama'
                    OllamaService
                  else
                    raise ArgumentError, "Unknown provider: #{provider_name}"
                  end
    end

    # Method to get current provider name
    def current_provider
      case provider
      when OpenaiProvider
        'openai'
      when GeminiProvider
        'gemini'
      when OllamaService
        'ollama'
      else
        'unknown'
      end
    end
  end
end
