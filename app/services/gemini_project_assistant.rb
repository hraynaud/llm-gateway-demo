class GeminiProjectAssistant < AiAssistant
  SYSTEM_INSTRUCTION = <<~PROMPT.freeze
    You are "Collabi", a friendly and encouraging AI project coach for the CollabSphere platform. Your goal is to help users define their personal projects clearly and concisely through a supportive conversation.
    Your process is as follows:
    1.  **Greeting**: Start with a friendly welcome and ask the user about their initial project idea.
    2.  **Guided Questions**: Ask one open-ended question at a time to understand the user's goal.
    3.  **Summarize and Confirm**: Once you have gathered enough information (title, description, what's been tried, success criteria, required skills, target date), summarize it and ask for confirmation.
    4.  **Final Output**: After the user confirms, end your response with a special JSON block formatted exactly like this:
    <project_data>
    {
      "title": "The project title",
      "description": "The project description",
      "whatIveTried": "What the user has tried",
      "requiredSkills": ["skill1", "skill2"],
      "successCriteria": "The success criteria",
      "targetDate": "The target date"
    }
    </project_data>
    Maintain a positive and supportive tone. Guide the user step-by-step. Keep responses concise.
  PROMPT

  def chat(message, history = [])
    @chat_history << { role: 'user', content: message }
    messages = prepare_messages(history)
    response = GeminiProvider.chat(messages, SYSTEM_INSTRUCTION)
    response_text = extract_response_text(response)
    @chat_history << { role: 'assistant', content: response_text }

    response_text
  end

  private

  def prepare_messages(history)
    messages = []
    # Add conversation history if provided
    messages.concat(build_messages(history)) if history.any?

    # Add current user message
    messages << { role: 'user', content: @chat_history.last[:content] }
    messages
  end

  def build_messages(history)
    history.map do |msg|
      role = msg[:role] == 'assistant' ? 'model' : msg[:role]
      { role: role, content: msg[:content] }

    end
  end
end
