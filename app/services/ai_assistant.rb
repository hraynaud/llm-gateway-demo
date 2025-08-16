class AiAssistant
  # System instructions for different modes
  PROJECT_WIZARD_SYSTEM_INSTRUCTION = <<~PROMPT
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

  ONBOARDING_SYSTEM_INSTRUCTION = <<~PROMPT
    You are "Collabi", a friendly and engaging AI onboarding specialist for the CollabSphere platform. Your goal is to conduct a short, conversational "mini-interview" to create a new user's profile.
    Your process is as follows:
    1.  **Greeting**: Start with a warm welcome.
    2.  **Ask for Name**: Ask for the user's full name.
    3.  **Ask for Skills & Interests**: Ask about their skills, hobbies, and interests.
    4.  **Ask about Life Experience**: Prompt for other experiences (e.g., languages spoken, places lived).
    5.  **Generate Bio & Summarize**: Generate a 1-2 sentence first-person bio. Summarize the full profile (Name, Bio, Skills) and ask for confirmation.
    6.  **Final Output**: After user confirmation, end your response with a special JSON block formatted exactly like this:
    <user_data>
    {
      "name": "The user's full name",
      "bio": "The AI-generated bio",
      "skills": ["skill1", "interest2"]
    }
    </user_data>
    Maintain a positive, step-by-step conversation.
  PROMPT

  MODES = {
    project: PROJECT_WIZARD_SYSTEM_INSTRUCTION,
    onboarding: ONBOARDING_SYSTEM_INSTRUCTION
  }.freeze

  def initialize(mode = :project)
    @mode = mode.to_sym
    @chat_history = []

    return if MODES.key?(@mode)

    raise ArgumentError, "Invalid mode: #{@mode}. Valid modes are: #{MODES.keys.join(', ')}"
  end

  def chat(message, history = [])
    # Add user message to history
    @chat_history << { role: 'user', content: message }
    # Prepare messages for AI service
    messages = prepare_messages(history)

    # Get response from AI service
    response = AiService.chat(messages)

    # Extract the response text
    response_text = extract_response_text(response)

    # Add AI response to history
    @chat_history << { role: 'assistant', content: response_text }
    response_text
  end

  def reset
    @chat_history = []
  end

  def get_history
    @chat_history.dup
  end

  private

  def prepare_messages(history)
    # Start with system instruction
    messages = [{ role: 'system', content: MODES[@mode] }]

    # Add conversation history if provided
    messages.concat(history.map { |msg| { role: msg[:role], content: msg[:content] } }) if history.any?

    # Add current user message
    messages << { role: 'user', content: @chat_history.last[:content] }

    messages
  end

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
