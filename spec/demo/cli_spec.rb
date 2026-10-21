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
