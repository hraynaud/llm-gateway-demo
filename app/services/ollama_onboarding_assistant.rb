class OllamaOnboardingAssistant < OllamaAssistant
  # Reuses the Gemini prompt, chosen for production because it gave the best experience.
  def system_instruction
    GeminiOnboardingAssistant::SYSTEM_INSTRUCTION
  end
end
