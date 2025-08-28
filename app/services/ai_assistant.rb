class AiAssistant


  # System instructions for different modes - GPT version (more forceful)





  def initialize
    @chat_history = []
  end

  def reset
    @chat_history = []
  end

  def get_history
    @chat_history.dup
  end

  private

  def extract_response_text(response)
    # Handle different response formats from different providers
    if response.is_a?(Enumerator)
      # For streaming responses, collect all chunks
      full_response = ''
      response.each do |chunk|
        if chunk.is_a?(Hash)
          # Handle GPT-5-mini format in chunks
          if chunk['choices'] && chunk['choices'][0] && chunk['choices'][0]['message']
            full_response += chunk['choices'][0]['message']['content']
          elsif chunk['candidates'] && chunk['candidates'][0] && chunk['candidates'][0]['content']
            full_response += chunk['candidates'][0]['content']['parts'][0]['text']
          # Handle other chunk formats
          elsif chunk['message'] && chunk['message']['content']
            full_response += chunk['message']['content']
          elsif chunk['content']
            full_response += chunk['content']
          end
        elsif chunk.is_a?(String)
          full_response += chunk
        end
      end
      full_response
    elsif response.is_a?(Hash)
      # For non-streaming responses
      # Handle GPT-5-mini format
      if response['choices'] && response['choices'][0] && response['choices'][0]['message']
        response['choices'][0]['message']['content']
      # Handle Gemini format
      elsif response['candidates'] && response['candidates'][0] && response['candidates'][0]['content']
        response['candidates'][0]['content']['parts'][0]['text']
      # Handle other OpenAI-like formats
      elsif response['response']
        response['response']
      else
        response.to_s
      end
    else
      response.to_s
    end
  end
end
