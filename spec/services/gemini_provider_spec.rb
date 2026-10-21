RSpec.describe GeminiProvider do
  let(:endpoint) { %r{\Ahttps://generativelanguage\.googleapis\.com/v1beta/models/[^:]+:generateContent} }
  let(:body) { { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Keywords: pottery' }] } }] } }

  before do
    stub_request(:post, endpoint)
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
    AiService.switch_provider('gemini')
  end

  it 'answers AiService.completion' do
    expect(AiService.completion('hi')).to eq(body)
  end

  it 'answers AiService.parse_completion' do
    expect(AiService.parse_completion(body)[:content]).to eq('Keywords: pottery')
  end

  it 'lets SummarizerService enrich text' do
    expect(SummarizerService.search('I throw stoneware')[:content]).to eq('Keywords: pottery')
  end

  it 'refuses embeddings with a message naming the alternatives' do
    expect { AiService.embedding('x') }.to raise_error(NotImplementedError, /ollama or openai/)
  end
end
