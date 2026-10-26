require 'tmpdir'
require_relative '../../demo/semantic_search'

RSpec.describe SemanticSearch do
  # Toy embedder: dimensions are [pilates, pottery, teach], with pilates weighted 2.
  let(:embedder_class) do
    Class.new do
      attr_reader :calls

      def initialize
        @calls = 0
      end

      def embedding(text)
        @calls += 1
        [text.match?(/pilates/i) ? 2.0 : 0.0, text.match?(/pottery|ceramics/i) ? 1.0 : 0.0, text.match?(/teach/i) ? 1.0 : 0.0]
      end
    end
  end
  let(:embedder) { embedder_class.new }
  let(:enrichments) do
    { 'I lead vinyasa flows' => 'Keywords: yoga, pilates',
      'I teach kids to swim' => 'Keywords: swimming, lifeguard',
      'I throw stoneware on the wheel' => 'Keywords: pottery, ceramics' }
  end
  let(:expander) { double('expander') }
  let(:people) do
    [{ 'name' => 'Mara', 'bio' => 'I lead vinyasa flows' },
     { 'name' => 'Kai', 'bio' => 'I teach kids to swim' },
     { 'name' => 'Tomasz', 'bio' => 'I throw stoneware on the wheel' }]
  end
  let(:dir) { Dir.mktmpdir }
  let(:cache_path) { File.join(dir, 'index.json') }

  before { allow(expander).to receive(:search) { |bio| { content: enrichments.fetch(bio) } } }
  after { FileUtils.remove_entry(dir) }

  def search(people_list = people, path = cache_path)
    described_class.new(people_list, cache_path: path, expander:, embedder:)
  end

  describe '.cosine' do
    it('is 1 for identical vectors') { expect(described_class.cosine([1, 2], [1, 2])).to be_within(1e-9).of(1.0) }
    it('is 0 for orthogonal vectors') { expect(described_class.cosine([1, 0], [0, 1])).to eq(0.0) }
    it('is -1 for opposite vectors') { expect(described_class.cosine([1, 0], [-1, 0])).to be_within(1e-9).of(-1.0) }
    it('is 0 when either vector is all zeros') { expect(described_class.cosine([0, 0], [1, 1])).to eq(0.0) }
  end

  describe '.cache_path_for' do
    let(:base) do
      { enrich_provider: 'ollama', enrich_model: 'qwen2:7b', embed_provider: 'ollama',
        embed_model: 'nomic-embed-text:latest', dir: }
    end

    it 'names both the enrichment and the embedding model' do
      expect(File.basename(described_class.cache_path_for(**base)))
        .to eq('.index-ollama-qwen2_7b--ollama-nomic-embed-text_latest.json')
    end

    it 'changes when only the enrichment model changes, so enrichments are never reused across models' do
      expect(described_class.cache_path_for(**base.merge(enrich_model: 'llama3'))).not_to eq(described_class.cache_path_for(**base))
    end

    it 'changes when only the embedding model changes' do
      expect(described_class.cache_path_for(**base.merge(embed_model: 'mxbai-embed-large'))).not_to eq(described_class.cache_path_for(**base))
    end

    it 'matches the gitignored /demo/.index-*.json pattern' do
      expect(File.basename(described_class.cache_path_for(**base))).to match(/\A\.index-.*\.json\z/)
    end
  end

  describe '#query' do
    it 'ranks by similarity to the enriched profile' do
      expect(search.index!.query('pottery', k: 2).map { |r| r[:name] }).to eq(%w[Tomasz Mara])
    end

    it 'returns score and enrichment with each match' do
      top = search.index!.query('pottery', k: 1).first
      expect(top).to include(name: 'Tomasz', enrichment: 'Keywords: pottery, ceramics')
      expect(top[:score]).to be_within(1e-9).of(1.0)
    end

    it 'indexes on first use if index! was not called' do
      expect(search.query('pottery', k: 1).first[:name]).to eq('Tomasz')
    end
  end

  describe '#compare' do
    it 'flags a person found only because of the enrichment' do
      expect(search.index!.compare('teach pilates', k: 1))
        .to eq([{ name: 'Mara', enriched_rank: 1, bare_rank: 2, gained: true }])
    end
  end

  describe 'enrichment shape' do
    it 'keeps JSON-shaped enrichment as text when the model ignores the markdown format' do
      allow(expander).to receive(:search) { { 'summary' => 'Yoga teacher', 'keywords' => ['pilates'] }.with_indifferent_access }
      enrichment = search.index!.query('pilates', k: 1).first[:enrichment]
      expect(enrichment).to include('pilates')
    end
  end

  describe 'cache' do
    it 'makes no LLM or embedding calls on a second index with the same cache' do
      search.index!
      second_embedder = embedder_class.new
      described_class.new(people, cache_path:, expander:, embedder: second_embedder).index!
      expect(expander).to have_received(:search).exactly(3).times
      expect(second_embedder.calls).to eq(0)
    end

    it 'rebuilds when people.json changes' do
      search.index!
      search(people.first(2)).index!
      expect(expander).to have_received(:search).exactly(5).times
    end

    it 'rebuilds when the cache file is corrupt' do
      File.write(cache_path, '{"people_digest": "x", "entr')
      search.index!
      expect(expander).to have_received(:search).exactly(3).times
    end
  end
end
