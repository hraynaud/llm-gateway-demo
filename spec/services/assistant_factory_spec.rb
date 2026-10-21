RSpec.describe AiService, 'assistant factories' do
  {
    'ollama' => [OllamaProjectAssistant, OllamaOnboardingAssistant],
    'openai' => [OpenaiProjectAssistant, OpenaiOnboardingAssistant],
    'gemini' => [GeminiProjectAssistant, GeminiOnboardingAssistant]
  }.each do |provider, (project_class, onboarding_class)|
    context "with AI_PROVIDER=#{provider}" do
      before { AiService.switch_provider(provider) }

      it("builds #{project_class}") { expect(AiService.project_assistant).to be_a(project_class) }
      it("builds #{onboarding_class}") { expect(AiService.onboarding_assistant).to be_a(onboarding_class) }
    end
  end
end
