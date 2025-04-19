class ChatService
  MAX_HISTORY_SIZE = 6 # Adjust based on token limit
  SUMMARY_PROMPT = %(
      Summarize the following conversation concisely while keeping
      key details relevant to the discussion.
      ).freeze

  def initialize
    @system_prompt = 'You are a helpful AI assistant skilled in helping people write concise
    summaries of a project they want to complete and suggesting key activities to perform
    to ensure success'
    @chat_history = []
  end

  def chat(user_input)
    @chat_history << { 'role' => 'user', 'content' => user_input }
    system_msg = { 'role' => 'system', 'content' => @system_prompt }
    @chat_history = summarize_chat(@chat_history) if @chat_history.size > MAX_HISTORY_SIZE

    messages = @chat_history.dup
    messages.unshift(system_msg)

    # Return the stream directly
    stream = OllamaService.chat(messages)

    # Capture the full response for chat history
    full_response = ''

    # Create a new Enumerator that will both yield the chunks and collect them
    Enumerator.new do |yielder|
      stream.each do |chunk|
        if chunk['message'] && chunk['message']['content']
          content = chunk['message']['content']
          full_response += content
          yielder << content
        elsif chunk['content']
          full_response += chunk['content']
          yielder << chunk['content']
        end
      end

      # After stream completes, add to chat history
      @chat_history << { 'role' => 'assistant', 'content' => full_response }
    end
  end

  private

  def summarize_chat(history)
    summary_msg = { 'role' => 'system', 'content' => SUMMARY_PROMPT }
    history_with_prompt = history.dup
    history_with_prompt.unshift(summary_msg)

    # For summarization, we don't need to stream
    summary_response = OllamaService.completion(history_with_prompt.to_json)
    summary_text = summary_response['response'] || summary_response[0]['response']

    Rails.logger.debug("Summary of previous conversation: #{summary_text}")

    [{ 'role' => 'system', 'content' => "Summary of previous conversation: #{summary_text}" }]
  end
end
