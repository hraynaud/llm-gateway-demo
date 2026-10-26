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

  # Table fixture: bios are names, enrichment is "<name>+", and every text maps to a fixed 2-D vector.
  let(:vectors) do
    { 'q' => [1.0, 0.0], 'p' => [0.0, 1.0],
      'Ana' => [0.5, 1.0], "Ana\nAna+" => [1.0, 0.0],
      'Ben' => [0.0, 1.0], "Ben\nBen+" => [1.0, 1.0],
      'Cy' => [1.0, 0.0], "Cy\nCy+" => [0.0, 1.0],
      'Di' => [0.0, 1.0], "Di\nDi+" => [0.0, 1.0],
      'Ed' => [0.0, 1.0], "Ed\nEd+" => [0.0, 1.0],
      'Fy' => [0.0, 1.0], "Fy\nFy+" => [0.0, 1.0] }
  end
  let(:table_embedder) do
    table = vectors
    Object.new.tap { |o| o.define_singleton_method(:embedding) { |text| table.fetch(text) } }
  end
  let(:table_expander) { Object.new.tap { |o| o.define_singleton_method(:search) { |bio| { content: "#{bio}+" } } } }
  let(:six) { %w[Ana Ben Cy Di Ed Fy].map { |n| { 'name' => n, 'bio' => n } } }
  let(:table_search) do
    described_class.new(six, cache_path: File.join(dir, 'table.json'), expander: table_expander, embedder: table_embedder).index!
  end

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

  describe '.strengths' do
    it 'measures each score in standard deviations from the query mean' do
      z = described_class.strengths([1.0, Math.sqrt(0.5), 0.0, 0.0, 0.0, 0.0])
      expect(z[0]).to be_within(1e-3).of(1.740)
      expect(z[1]).to be_within(1e-3).of(1.028)
    end

    it('is all zero when every score is equal') { expect(described_class.strengths([0.1, 0.1, 0.1])).to eq([0.0, 0.0, 0.0]) }
    it('is empty for no scores') { expect(described_class.strengths([])).to eq([]) }
  end

  describe '.strong?' do
    it('is true at the cutoff') { expect(described_class.strong?(1.5)).to be true }
    it('is false just below it') { expect(described_class.strong?(1.4999)).to be false }
  end

  describe '#query strength' do
    it 'marks strong and weak matches' do
      rows = table_search.query('q', k: 2)
      expect(rows.map { |r| [r[:name], r[:strong]] }).to eq([['Ana', true], ['Ben', false]])
      expect(rows.first[:strength]).to be_within(1e-3).of(1.740)
    end
  end

  describe '#compare' do
    it 'rescues a strong match the bare bio ranks outside the top k' do
      row = table_search.compare('q', k: 1).first
      expect(row).to include(name: 'Ana', enriched_rank: 1, strong: true, bare_rank: 2, rank_change: 1, gained: true)
      expect(row[:enriched_score]).to be_within(1e-9).of(1.0)
      expect(row[:bare_score]).to be_within(1e-3).of(0.447)
      expect(row[:strength]).to be_within(1e-3).of(1.740)
    end

    it 'does not flag a weak match even when the bare bio ranks it outside the top k' do
      ben = table_search.compare('q', k: 2).find { |r| r[:name] == 'Ben' }
      expect(ben).to include(strong: false, bare_rank: 3, rank_change: 1, gained: false)
    end

    it 'reports a person enrichment moved down' do
      cy = table_search.compare('q', k: 3).find { |r| r[:name] == 'Cy' }
      expect(cy).to include(enriched_rank: 3, bare_rank: 1, rank_change: -2, gained: false)
    end

    it 'flags nobody when every match is weak' do
      rows = table_search.compare('p', k: 5)
      expect(rows.map { |r| r[:strong] }).to all(be false)
      expect(rows.map { |r| r[:gained] }).to all(be false)
    end
  end

  describe '#evaluate' do
    let(:queries) do
      [{ 'query' => 'q', 'expect' => ['Ana'], 'difficulty' => 'hard' },
       { 'query' => 'q', 'expect' => ['Cy'], 'difficulty' => 'medium' },
       { 'query' => 'p', 'expect' => ['Di'], 'difficulty' => 'easy' },
       { 'query' => 'q', 'expect' => ['Zed'], 'difficulty' => 'hard' }]
    end
    let(:result) { table_search.evaluate(queries, k: 2) }

    it 'reports the best rank of an expected person with and without enrichment' do
      expect(result[:rows].map { |r| [r[:enriched_rank], r[:bare_rank], r[:verdict]] })
        .to eq([[1, 2, 'helped'], [3, 1, 'hurt'], [2, 2, 'same'], [nil, nil, 'same']])
    end

    it 'keeps each query and its difficulty' do
      expect(result[:rows].map { |r| [r[:query], r[:difficulty]] }).to eq([%w[q hard], %w[q medium], %w[p easy], %w[q hard]])
    end

    it 'summarises hits and verdicts' do
      expect(result[:summary]).to eq(total: 4, k: 2, enriched_hit1: 1, enriched_hitk: 2, bare_hit1: 1, bare_hitk: 3,
                                     helped: 1, hurt: 1, same: 2)
    end

    it 'takes the best rank when several people are expected' do
      row = table_search.evaluate([{ 'query' => 'q', 'expect' => %w[Ben Ana], 'difficulty' => 'hard' }])[:rows].first
      expect(row).to include(enriched_rank: 1, bare_rank: 2)
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
