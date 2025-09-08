class OpenAiAssistant < AiAssistant
  def chat(message, history = [])
    @chat_history << { role: 'user', content: message }
    messages = prepare_messages(history)
    response = OpenaiProvider.bot.chat(messages, system_instruction)
    response_text = extract_response_text(response)
    @chat_history << { role: 'assistant', content: response_text }

    response_text
  end

  def system_instruction
    nil
  end

  private

  def prepare_messages(history)
    messages = []
    messages.concat(build_messages(history)) if history.any?
    messages << { role: 'user', content: @chat_history.last[:content] }
    messages
  end

  def build_messages(history)
    history.map do |msg|
      role = msg[:role] == 'assistant' ? 'model' : msg[:role]
      { role: role, content: msg[:content] }

    end
  end

  def extract_response_text(response)
    if response.is_a?(Enumerator)
      # For streaming responses, collect all chunks
      build_from_chunks(response)
    elsif response.is_a?(Hash)
      response['candidates'][0]['content']['parts'][0]['text']
    else
      response.to_s
    end
  end

  def build_from_chunks(response)
    full_response = ''
    response.each do |chunk|
      if chunk.is_a?(Hash)
        full_response += chunk['candidates'][0]['content']['parts'][0]['text']
      elsif chunk.is_a?(String)
        full_response += chunk
      end
    end
    full_response
  end
end
