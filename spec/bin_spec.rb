require 'open3'

# Each script must fail fast and helpfully before any network call.
RSpec.describe 'bin scripts' do
  let(:root) { File.expand_path('..', __dir__) }

  def run(env, *cmd, stdin: '')
    Open3.capture3(env, *cmd, stdin_data: stdin, chdir: root)
  end

  it 'bin/search without a query prints usage' do
    _out, err, status = run({}, 'bin/search')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('Usage: bin/search')
  end

  it 'bin/search refuses gemini as the embedding provider before indexing' do
    _out, err, status = run({ 'EMBEDDING_MODEL_PROVIDER' => 'gemini' }, 'bin/search', 'pottery')
    expect(status.exitstatus).to eq(1)
    expect(err).to include("Gemini can't produce embeddings")
  end

  it 'bin/search with AI_PROVIDER=gemini and no key fails on the key, not on indexing' do
    _out, err, status = run({ 'AI_PROVIDER' => 'gemini', 'GEMINI_API_KEY' => nil }, 'bin/search', 'pottery')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('GEMINI_API_KEY')
  end

  it 'bin/search reports a missing key for an OpenAI embedding provider' do
    _out, err, status = run({ 'EMBEDDING_MODEL_PROVIDER' => 'openai', 'OPENAI_API_KEY' => nil }, 'bin/search', 'pottery')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('EMBEDDING_MODEL_PROVIDER=openai needs OPENAI_API_KEY')
  end

  it 'bin/search --eval refuses a query' do
    _out, err, status = run({}, 'bin/search', '--eval', 'pottery')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('Usage: bin/search')
  end

  it 'bin/search --eval refuses --compare' do
    _out, err, status = run({}, 'bin/search', '--eval', '--compare')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('Usage: bin/search')
  end

  it 'bin/chat reports a missing key for a hosted provider' do
    _out, err, status = run({ 'AI_PROVIDER' => 'openai', 'OPENAI_API_KEY' => nil }, 'bin/chat')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('OPENAI_API_KEY')
  end

  it 'bin/onboard exits cleanly on end of input' do
    _out, _err, status = run({}, 'bin/onboard', stdin: '')
    expect(status).to be_success
  end
end
