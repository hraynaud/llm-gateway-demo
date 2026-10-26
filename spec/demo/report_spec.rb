require_relative '../../demo/report'

RSpec.describe Demo::Report do
  let(:rescued) do
    { name: 'Ana', enriched_rank: 1, enriched_score: 1.0, strength: 1.74, strong: true, bare_rank: 2, bare_score: 0.447,
      rank_change: 1, gained: true }
  end
  let(:weak) do
    { name: 'Ben', enriched_rank: 2, enriched_score: 0.707, strength: 1.03, strong: false, bare_rank: 3, bare_score: 0.0,
      rank_change: 1, gained: false }
  end
  let(:dropped) do
    { name: 'Cy', enriched_rank: 3, enriched_score: 0.0, strength: -0.69, strong: false, bare_rank: 1, bare_score: 1.0,
      rank_change: -2, gained: false }
  end

  it 'names both models in the header' do
    expect(described_class.header(enrich_provider: 'gemini', enrich_model: 'gemini-2.5-flash',
                                  embed_provider: 'ollama', embed_model: 'mxbai-embed-large'))
      .to eq('Enrichment: gemini (gemini-2.5-flash) · Embeddings: ollama (mxbai-embed-large)')
  end

  it 'formats strength in standard deviations' do
    expect(described_class.strength(1.74)).to eq('+1.7σ')
    expect(described_class.strength(-0.69)).to eq('-0.7σ')
    expect(described_class.strength(1.46)).to eq('+1.4σ')
    expect(described_class.strength(1.5)).to eq('+1.5σ')
  end

  it 'shows movement in both directions' do
    expect(described_class.movement(2)).to eq('↑2')
    expect(described_class.movement(-2)).to eq('↓2')
    expect(described_class.movement(0)).to eq('')
  end

  describe '.compare_lines' do
    let(:lines) { described_class.compare_lines([rescued, weak, dropped]) }

    it 'flags only the rescued row' do
      expect(lines[1]).to include('Ana', '+1.7σ', '↑1')
      expect(lines[1]).to end_with('<- found via enrichment')
      expect(lines.count { |l| l.include?('found via enrichment') }).to eq(1)
    end

    it 'divides weak rows from strong ones and shows downward moves' do
      expect(lines[2]).to eq(described_class::DIVIDER)
      expect(lines[3]).to include('Ben')
      expect(lines[4]).to include('Cy', '↓2')
    end

    it 'puts the divider first when nothing is strong' do
      expect(described_class.compare_lines([weak, dropped])[1]).to eq(described_class::DIVIDER)
    end

    it 'aligns the bare and move headers with the row columns' do
      bare_column = lines[1].index(format('%2d %.3f', rescued[:bare_rank], rescued[:bare_score]))
      expect(lines[0].index('bare')).to eq(bare_column)
      expect(lines[0].index('move')).to eq(lines[1].index('↑1'))
    end

    it 'never flags a weak row, even when it is marked gained' do
      flagged = described_class.compare_lines([rescued, weak.merge(gained: true)])
      expect(flagged[3]).to include('Ben')
      expect(flagged[3]).not_to include('found via enrichment')
      expect(flagged.count { |l| l.include?('found via enrichment') }).to eq(1)
    end
  end

  it 'formats plain results with strength and the divider' do
    results = [{ name: 'Ana', score: 1.0, strength: 1.74, strong: true, enrichment: 'x' },
               { name: 'Ben', score: 0.707, strength: 1.03, strong: false, enrichment: 'y' }]
    expect(described_class.query_lines(results)).to eq(['1.000 +1.7σ  Ana', described_class::DIVIDER, '0.707 +1.0σ  Ben'])
  end

  describe '.eval_lines' do
    let(:result) do
      { rows: [{ query: 'q', difficulty: 'hard', enriched_rank: 1, bare_rank: 2, verdict: 'helped' },
               { query: 'z', difficulty: 'easy', enriched_rank: nil, bare_rank: nil, verdict: 'same' }],
        summary: { total: 2, k: 5, enriched_hit1: 1, enriched_hitk: 1, bare_hit1: 0, bare_hitk: 1, helped: 1, hurt: 0, same: 1 } }
    end
    let(:lines) { described_class.eval_lines(result) }

    it('shows a not-found rank as "-"') { expect(lines[2].split).to eq(%w[z easy - - same]) }

    it 'ends with the summary' do
      expect(lines.last(3)).to eq(['enriched: 1/2 at #1, 1/2 in top 5',
                                   'bare:     0/2 at #1, 1/2 in top 5',
                                   'enrichment helped 1, hurt 0, same 1'])
    end
  end
end
