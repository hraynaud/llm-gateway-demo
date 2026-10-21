require 'tmpdir'
require_relative '../../demo/semantic_search'

# Opt-in: LIVE=1 bundle exec rspec spec/live
# Needs `ollama serve` plus the configured LLM and EMBEDDING_MODEL pulled.
RSpec.describe 'live Ollama', :live do
  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end

  it 'answers a non-streaming chat turn' do
    expect(ChatService.new.chat_non_streaming('Reply with one word: ready').strip).not_to be_empty
  end

  it 'answers an onboarding turn through the Ollama assistant' do
    assistant = AiService.onboarding_assistant
    expect(assistant).to be_a(OllamaOnboardingAssistant)
    expect(assistant.chat('Hi').strip).not_to be_empty
  end

  it 'enriches, embeds and ranks real profiles' do
    people = [{ 'name' => 'Mara', 'bio' => 'I teach vinyasa three mornings a week.' },
              { 'name' => 'Tomasz', 'bio' => 'I throw stoneware on the wheel.' }]
    Dir.mktmpdir do |dir|
      results = SemanticSearch.new(people, cache_path: File.join(dir, 'i.json')).index!.query('pottery studio', k: 2)
      expect(results.first[:name]).to eq('Tomasz')
      expect(results.map { |r| r[:score] }).to all(be_between(-1.0, 1.0))
    end
  end
end
