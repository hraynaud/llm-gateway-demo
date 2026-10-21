require 'open3'

RSpec.describe 'config/boot.rb' do
  let(:root) { File.expand_path('..', __dir__) }

  it 'loads every file in app/services' do
    services = Dir[File.join(root, 'app/services/*.rb')].map { |f| File.basename(f, '.rb') }
    loaded = $LOADED_FEATURES.map { |f| File.basename(f, '.rb') }
    expect(services - loaded).to be_empty
  end

  it 'does not load the Rails controllers' do
    expect(defined?(Api)).to be_nil
  end

  it 'provides a Rails.logger shim' do
    expect(Rails.logger).to be_a(Logger)
  end

  it 'provides indifferent hash access' do
    expect({ 'content' => 'x' }.with_indifferent_access[:content]).to eq('x')
  end

  it 'defaults to the Ollama provider' do
    expect(AiService.provider).to eq(OllamaService)
  end

  it 'points Ollama at localhost when OLLAMA_SERVER_ADDRESS is unset' do
    out, status = Open3.capture2e(
      { 'OLLAMA_SERVER_ADDRESS' => nil },
      RbConfig.ruby, '-rbundler/setup', '-e',
      'require "./config/boot"; print OllamaService::OLLAMA_SERVER_ADDRESS',
      chdir: root
    )
    expect(status).to be_success, out
    expect(out).to eq('http://localhost:11434')
  end
end
