class OpenaiAssistant < AiAssistant
  def chat(message, history = [])
    @chat_history << { role: 'user', content: message }
    messages = prepare_messages(history)
    response = OpenaiProvider.chat(messages)
    response_text = extract_response_text(response)
    @chat_history << { role: 'assistant', content: response_text }

    response_text
  end

  def system_instruction
    nil
  end

  private

  # OpenAI takes the system prompt as the first message and the standard
  # user/assistant roles; the base class's extract_response_text reads `choices`.
  def prepare_messages(history)
    messages = []
    messages << { role: 'system', content: system_instruction } if system_instruction
    messages.concat(history.map { |msg| { role: msg[:role], content: msg[:content] } })
    messages << { role: 'user', content: @chat_history.last[:content] }
    messages
  end
end
