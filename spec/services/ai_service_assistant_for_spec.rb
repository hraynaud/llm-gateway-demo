RSpec.describe AiService, '.assistant_for' do
  let(:project) { instance_double(AiAssistant) }
  let(:onboarding) { instance_double(AiAssistant) }

  before do
    allow(AiService).to receive(:project_assistant).and_return(project)
    allow(AiService).to receive(:onboarding_assistant).and_return(onboarding)
  end

  it 'returns the project assistant for :project' do
    expect(AiService.assistant_for(:project)).to be(project)
  end

  it 'returns the onboarding assistant for :onboarding' do
    expect(AiService.assistant_for(:onboarding)).to be(onboarding)
  end

  it 'accepts string modes, as they arrive from params or the CLI' do
    expect(AiService.assistant_for('onboarding')).to be(onboarding)
  end

  it 'raises ArgumentError for an unknown mode' do
    expect { AiService.assistant_for(:poetry) }.to raise_error(ArgumentError, /poetry/)
  end

  it 'raises ArgumentError for a nil mode' do
    expect { AiService.assistant_for(nil) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError for a non-string, non-symbol mode' do
    expect { AiService.assistant_for(5) }.to raise_error(ArgumentError)
  end
end
