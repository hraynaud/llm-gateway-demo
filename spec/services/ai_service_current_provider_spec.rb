RSpec.describe AiService, '.current_provider' do
  it 'is ollama by default' do
    expect(AiService.current_provider).to eq('ollama')
  end

  %w[openai gemini ollama].each do |name|
    it "is #{name} after switch_provider('#{name}')" do
      AiService.switch_provider(name)
      expect(AiService.current_provider).to eq(name)
    end
  end
end
