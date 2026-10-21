RSpec.describe ChatService do
  subject(:service) { described_class.new }

  def summary_request?(prompt)
    JSON.parse(prompt).first['content'].include?('Summarize the following conversation')
  end

  {
    'Ollama (array of events)' => [[{ 'response' => 'from ollama', 'done' => true }], 'from ollama'],
    'OpenAI (choices)' => [{ 'choices' => [{ 'message' => { 'content' => 'from openai' } }] }, 'from openai'],
    'Gemini (candidates)' => [{ 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'from gemini' }] } }] }, 'from gemini']
  }.each do |shape, (response, expected)|
    it "reads the reply from the #{shape} shape" do
      allow(AiService).to receive(:completion).and_return(response)
      expect(service.chat_non_streaming('hi')).to eq(expected)
    end
  end

  it 'summarises once history passes MAX_HISTORY_SIZE and sends the summary as context' do
    prompts = []
    allow(AiService).to receive(:completion) do |prompt|
      prompts << prompt
      summary_request?(prompt) ? [{ 'response' => 'SUMMARY' }] : [{ 'response' => 'ok' }]
    end

    4.times { |i| service.chat_non_streaming("turn #{i}") }

    expect(prompts.count { |p| summary_request?(p) }).to eq(1)
    expect(prompts.last).to include('Summary of previous conversation: SUMMARY')
  end

  it 'summarises on the streaming path without raising' do
    allow(AiService).to receive(:completion).and_return([{ 'response' => 'SUMMARY' }])
    allow(AiService).to receive(:chat) { [{ 'message' => { 'content' => 'ok' } }].each }

    replies = Array.new(4) { |i| service.chat("turn #{i}").to_a.join }

    expect(replies).to all(eq('ok'))
    expect(AiService).to have_received(:completion).once
  end
end
