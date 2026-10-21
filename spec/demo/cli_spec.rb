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
    it('uses the OpenAI default for openai') { expect(described_class.embedding_model('openai')).to eq(ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small')) }
  end
end
