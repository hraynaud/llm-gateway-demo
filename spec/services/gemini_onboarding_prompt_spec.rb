RSpec.describe GeminiOnboardingAssistant do
  let(:prompt) { described_class::SYSTEM_INSTRUCTION }

  it 'contains no pasted TypeScript' do
    expect(prompt).not_to include('export default', 'isValidMode', 'const instructions', 'VercelRequest', '`;')
  end

  it 'still asks for the <user_data> JSON block' do
    expect(prompt).to include('<user_data>', '</user_data>')
  end

  it 'ends with the closing instruction' do
    expect(prompt).to end_with("Always format the summary cleanly with proper spacing and structure.\n")
  end
end
