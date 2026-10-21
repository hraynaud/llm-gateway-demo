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

  it 'bin/search refuses gemini before indexing' do
    _out, err, status = run({ 'AI_PROVIDER' => 'gemini', 'GEMINI_API_KEY' => 'k' }, 'bin/search', 'pottery')
    expect(status.exitstatus).to eq(1)
    expect(err).to include('ollama or openai')
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
