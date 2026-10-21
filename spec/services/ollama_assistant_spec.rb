# Stubbed at the OllamaService boundary rather than HTTP: ollama-ai parses
# server-sent events chunk by chunk, and WebMock delivers a body in one piece.
# spec/live covers the real HTTP path.
RSpec.describe OllamaOnboardingAssistant do
  subject(:assistant) { described_class.new }

  let(:sent) { [] }
  let(:events) do
    [{ 'message' => { 'content' => 'Hel' }, 'done' => false },
     { 'message' => { 'content' => 'lo!' }, 'done' => true }]
  end

  before do
    allow(OllamaService).to receive(:chat) do |messages|
      sent.replace(messages)
      events.each
    end
  end

  it 'reuses the Gemini onboarding prompt' do
    expect(assistant.system_instruction).to eq(GeminiOnboardingAssistant::SYSTEM_INSTRUCTION)
  end

  it 'joins the streamed chunks into one reply' do
    expect(assistant.chat('Hi')).to eq('Hello!')
  end

  it 'sends the system prompt first and history roles unchanged' do
    assistant.chat('I am Ada', [{ role: 'user', content: 'Hi' }, { role: 'assistant', content: 'Hello!' }])

    expect(sent.first).to eq(role: 'system', content: GeminiOnboardingAssistant::SYSTEM_INSTRUCTION)
    expect(sent.drop(1).map { |m| m[:role] }).to eq(%w[user assistant user])
    expect(sent.last[:content]).to eq('I am Ada')
  end

  it 'records the user and assistant turns' do
    assistant.chat('Hi')
    expect(assistant.get_history).to eq([{ role: 'user', content: 'Hi' }, { role: 'assistant', content: 'Hello!' }])
  end
end

RSpec.describe OllamaProjectAssistant do
  it 'reuses the Gemini project prompt' do
    expect(described_class.new.system_instruction).to eq(GeminiProjectAssistant::SYSTEM_INSTRUCTION)
  end
end
