RSpec.describe OpenaiAssistant do
  let(:url) { 'https://api.openai.com/v1/chat/completions' }
  let(:reply) { { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Hi Ada!' } }] } }
  let(:history) { [{ role: 'user', content: 'hello' }, { role: 'assistant', content: 'Welcome!' }] }

  before do
    stub_request(:post, url)
      .to_return(status: 200, body: reply.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  {
    OpenaiOnboardingAssistant => :ONBOARDING_SYSTEM_INSTRUCTION_GPT,
    OpenaiProjectAssistant => :PROJECT_WIZARD_SYSTEM_INSTRUCTION_GPT
  }.each do |klass, prompt_constant|
    describe klass do
      subject(:assistant) { klass.new }

      it "uses #{prompt_constant} as its system instruction" do
        expect(assistant.system_instruction).to eq(klass.const_get(prompt_constant))
      end

      it 'returns the reply text' do
        expect(assistant.chat('I am Ada', history)).to eq('Hi Ada!')
      end

      it 'sends the system prompt first and history roles unchanged' do
        assistant.chat('I am Ada', history)

        expect(a_request(:post, url).with { |req|
          messages = JSON.parse(req.body)['messages']
          messages.first == { 'role' => 'system', 'content' => klass.const_get(prompt_constant) } &&
            messages.drop(1).map { |m| m['role'] } == %w[user assistant user] &&
            messages.last['content'] == 'I am Ada'
        }).to have_been_made.once
      end

      it 'records the user and assistant turns' do
        assistant.chat('I am Ada', history)
        expect(assistant.get_history).to eq([
          { role: 'user', content: 'I am Ada' },
          { role: 'assistant', content: 'Hi Ada!' }
        ])
      end
    end
  end
end
