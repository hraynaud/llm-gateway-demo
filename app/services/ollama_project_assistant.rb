class OllamaProjectAssistant < OllamaAssistant
  # Reuses the Gemini prompt, chosen for production because it gave the best experience.
  def system_instruction
    GeminiProjectAssistant::SYSTEM_INSTRUCTION
  end
end
