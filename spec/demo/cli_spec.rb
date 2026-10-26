require_relative '../../demo/cli'

RSpec.describe Demo::CLI do
  describe '.missing_key_message' do
    it 'names the missing key for a hosted provider' do
      expect(described_class.missing_key_message('openai', {})).to include('OPENAI_API_KEY')
      expect(described_class.missing_key_message('gemini', { 'GEMINI_API_KEY' => '' })).to include('GEMINI_API_KEY')
    end

    it 'is nil when the key is present or the provider is local' do
      expect(described_class.missing_key_message('openai', { 'OPENAI_API_KEY' => 'k' })).to be_nil
      expect(described_class.missing_key_message('ollama', {})).to be_nil
    end
  end

  describe '.missing_key_message with a setting name' do
    it 'names the setting that chose the provider' do
      message = described_class.missing_key_message('openai', {}, setting: 'EMBEDDING_MODEL_PROVIDER')
      expect(message).to include('EMBEDDING_MODEL_PROVIDER=openai needs OPENAI_API_KEY')
    end
  end

  describe '.embedding_provider' do
    it 'uses EMBEDDING_MODEL_PROVIDER when it is ollama or openai' do
      expect(described_class.embedding_provider({ 'EMBEDDING_MODEL_PROVIDER' => 'openai' }, 'ollama')).to eq(['openai', nil])
    end

    it 'ignores case and surrounding spaces' do
      expect(described_class.embedding_provider({ 'EMBEDDING_MODEL_PROVIDER' => ' OLLAMA ' }, 'openai')).to eq(['ollama', nil])
    end

    it 'refuses gemini and says what to use instead' do
      name, error = described_class.embedding_provider({ 'EMBEDDING_MODEL_PROVIDER' => 'gemini' }, 'ollama')
      expect(name).to be_nil
      expect(error).to include("Gemini can't produce embeddings", 'EMBEDDING_MODEL_PROVIDER=ollama or openai')
    end

    it 'refuses an unknown value and names the allowed ones' do
      name, error = described_class.embedding_provider({ 'EMBEDDING_MODEL_PROVIDER' => 'cohere' }, 'ollama')
      expect(name).to be_nil
      expect(error).to include('ollama or openai', '"cohere"')
    end

    it 'follows the chat provider when it can embed' do
      expect(described_class.embedding_provider({}, 'openai')).to eq(['openai', nil])
    end

    it 'falls back to ollama when the chat provider is gemini' do
      expect(described_class.embedding_provider({}, 'gemini')).to eq(['ollama', nil])
    end

    it 'treats an empty setting as unset' do
      expect(described_class.embedding_provider({ 'EMBEDDING_MODEL_PROVIDER' => '' }, 'openai')).to eq(['openai', nil])
    end
  end

  describe '.embedder_for' do
    it('maps ollama to OllamaService') { expect(described_class.embedder_for('ollama')).to eq(OllamaService) }
    it('maps openai to OpenaiProvider') { expect(described_class.embedder_for('openai')).to eq(OpenaiProvider) }
    it('rejects gemini') { expect { described_class.embedder_for('gemini') }.to raise_error(KeyError) }
  end

  describe '.enrichment_model' do
    around do |example|
      saved = ENV.to_h.slice('OPENAI_LLM', 'GEMINI_LLM')
      example.run
    ensure
      %w[OPENAI_LLM GEMINI_LLM].each { |k| saved.key?(k) ? ENV[k] = saved[k] : ENV.delete(k) }
    end

    it('uses the Ollama LLM for ollama') { expect(described_class.enrichment_model('ollama')).to eq(OllamaService::LLM) }

    it 'uses OPENAI_LLM or gpt-5-mini for openai' do
      ENV.delete('OPENAI_LLM')
      expect(described_class.enrichment_model('openai')).to eq('gpt-5-mini')
      ENV['OPENAI_LLM'] = 'pinned'
      expect(described_class.enrichment_model('openai')).to eq('pinned')
    end

    it 'uses GEMINI_LLM or gemini-2.5-flash for gemini' do
      ENV.delete('GEMINI_LLM')
      expect(described_class.enrichment_model('gemini')).to eq('gemini-2.5-flash')
    end
  end

  describe '.search_unsupported_message' do
    it('refuses gemini') { expect(described_class.search_unsupported_message('gemini')).to include('ollama or openai') }
    it('allows ollama') { expect(described_class.search_unsupported_message('ollama')).to be_nil }
  end

  describe '.error_message' do
    it 'explains an unreachable Ollama' do
      error = Ollama::Errors::RequestError.new('Failed to open TCP connection', request: Faraday::ConnectionFailed.new('refused'))
      expect(described_class.error_message(error)).to include("Can't reach Ollama", 'ollama serve', 'AI_PROVIDER')
    end

    it 'suggests a pull when Ollama does not have the model' do
      error = Ollama::Errors::RequestError.new('404', request: Faraday::ResourceNotFound.new('404', { status: 404 }))
      expect(described_class.error_message(error)).to include("ollama pull #{OllamaService::LLM}")
    end

    it 'reports the HTTP status for a 400, not "can\'t reach"' do
      cause = Faraday::BadRequestError.new('400', { status: 400, body: '{"error":"x does not support chat"}' })
      message = described_class.error_message(Ollama::Errors::RequestError.new('400', request: cause))
      expect(message).to include('HTTP 400', 'does not support chat')
      expect(message).not_to include("Can't reach")
    end

    it 'reports the HTTP status for a 500, not "can\'t reach"' do
      cause = Faraday::ServerError.new('500', { status: 500, body: 'oom' })
      message = described_class.error_message(Ollama::Errors::RequestError.new('500', request: cause))
      expect(message).to include('HTTP 500', 'oom')
      expect(message).not_to include("Can't reach")
    end

    it 'explains an Ollama timeout as unreachable' do
      error = Ollama::Errors::RequestError.new('timeout', request: Faraday::TimeoutError.new('timed out'))
      expect(described_class.error_message(error)).to include("Can't reach Ollama")
    end

    it 'passes NotImplementedError messages through' do
      expect(described_class.error_message(NotImplementedError.new('no embeddings'))).to eq('no embeddings')
    end
  end

  describe '.extract_tagged_json' do
    it 'parses the tagged block' do
      text = "Great!\n<user_data>\n{\"name\": \"Ada\"}\n</user_data>"
      expect(described_class.extract_tagged_json(text, 'user_data')).to eq('name' => 'Ada')
    end

    it 'returns :invalid for malformed JSON, as small models sometimes produce' do
      expect(described_class.extract_tagged_json('<user_data>{name: Ada,}</user_data>', 'user_data')).to eq(:invalid)
    end

    it 'returns nil when there is no block' do
      expect(described_class.extract_tagged_json('What is your name?', 'user_data')).to be_nil
    end
  end

  describe '.embedding_model' do
    it('uses the Ollama embedding model by default') { expect(described_class.embedding_model('ollama')).to eq(OllamaService::EMBEDDING_MODEL) }

    context 'with openai' do
      around do |example|
        saved = ENV.fetch('OPENAI_EMBEDDING_MODEL', nil)
        example.run
      ensure
        saved.nil? ? ENV.delete('OPENAI_EMBEDDING_MODEL') : ENV['OPENAI_EMBEDDING_MODEL'] = saved
      end

      it 'uses OPENAI_EMBEDDING_MODEL when set' do
        ENV['OPENAI_EMBEDDING_MODEL'] = 'pinned-model'
        expect(described_class.embedding_model('openai')).to eq('pinned-model')
      end

      it 'falls back to text-embedding-3-small when unset' do
        ENV.delete('OPENAI_EMBEDDING_MODEL')
        expect(described_class.embedding_model('openai')).to eq('text-embedding-3-small')
      end
    end
  end
end
