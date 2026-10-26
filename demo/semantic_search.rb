require 'digest'
require 'fileutils'
require 'json'

# Added 2026, clean-room: enrichment-based retrieval built on the original
# SummarizerService prompt. Each profile is enriched once by the LLM (summary
# plus related terms), embedded, and ranked against the raw query by cosine
# similarity. `compare` also ranks the un-enriched bio, and flags only strong
# matches the bio alone would have missed.
class SemanticSearch
  # A match is strong when its score sits this many standard deviations above the query's
  # average. Relative on purpose: each embedding model scores on its own scale.
  STRONG_Z = 1.5

  # One cache per model pair: switching either the enrichment or the embedding model rebuilds.
  def self.cache_path_for(enrich_provider:, enrich_model:, embed_provider:, embed_model:, dir: __dir__)
    slug = ->(text) { text.gsub(/[^A-Za-z0-9._-]/, '_') }
    File.join(dir, ".index-#{slug.call("#{enrich_provider}-#{enrich_model}")}--#{slug.call("#{embed_provider}-#{embed_model}")}.json")
  end

  def self.cosine(a, b)
    dot = a.zip(b).sum { |x, y| x * y }
    norms = Math.sqrt(a.sum { |x| x * x }) * Math.sqrt(b.sum { |x| x * x })
    norms.zero? ? 0.0 : dot / norms
  end

  def self.strengths(scores)
    return [] if scores.empty?

    mean = scores.sum / scores.size
    sd = Math.sqrt(scores.sum { |s| (s - mean)**2 } / scores.size)
    return scores.map { 0.0 } if sd < 1e-12

    scores.map { |s| (s - mean) / sd }
  end

  def self.strong?(strength)
    strength >= STRONG_Z
  end

  def initialize(people, cache_path:, expander: SummarizerService, embedder: AiService)
    @people = people
    @cache_path = cache_path
    @expander = expander
    @embedder = embedder
  end

  def index!
    @entries = load_cache || build_index.tap { |entries| write_cache(entries) }
    self
  end

  def query(text, k: 5)
    ranked = rank(@embedder.embedding(text), 'vector')
    z = self.class.strengths(ranked.map(&:last))
    ranked.first(k).each_with_index.map do |(entry, score), i|
      { name: entry['name'], score:, strength: z[i], strong: self.class.strong?(z[i]), enrichment: entry['enrichment'] }
    end
  end

  def compare(text, k: 5)
    vector = @embedder.embedding(text)
    enriched = rank(vector, 'vector')
    bare = rank(vector, 'bare_vector')
    z = self.class.strengths(enriched.map(&:last))
    enriched.first(k).each_with_index.map do |(entry, score), i|
      bare_index = bare.index { |other, _| other.equal?(entry) }
      strong = self.class.strong?(z[i])
      { name: entry['name'], enriched_rank: i + 1, enriched_score: score, strength: z[i], strong:,
        bare_rank: bare_index + 1, bare_score: bare[bare_index][1], rank_change: bare_index - i,
        gained: strong && bare_index + 1 > k }
    end
  end

  # Scores a fixed query set: where the expected people land with and without enrichment.
  def evaluate(queries, k: 5)
    rows = queries.map do |q|
      vector = @embedder.embedding(q['query'])
      enriched_rank = best_rank(rank(vector, 'vector'), q['expect'])
      bare_rank = best_rank(rank(vector, 'bare_vector'), q['expect'])
      { query: q['query'], difficulty: q['difficulty'], enriched_rank:, bare_rank:,
        verdict: verdict(enriched_rank, bare_rank) }
    end
    { rows:, summary: summarize(rows, k) }
  end

  private

  # nil when none of the expected people is indexed, which the report shows as "-".
  def best_rank(ranked, names)
    ranked.each_with_index.filter_map { |(entry, _score), i| i + 1 if names.include?(entry['name']) }.min
  end

  def verdict(enriched, bare)
    return 'same' if enriched == bare
    return 'hurt' if enriched.nil?
    return 'helped' if bare.nil?

    enriched < bare ? 'helped' : 'hurt'
  end

  def summarize(rows, k)
    hits = ->(field, limit) { rows.count { |r| r[field] && r[field] <= limit } }
    { total: rows.size, k:,
      enriched_hit1: hits.call(:enriched_rank, 1), enriched_hitk: hits.call(:enriched_rank, k),
      bare_hit1: hits.call(:bare_rank, 1), bare_hitk: hits.call(:bare_rank, k),
      helped: rows.count { |r| r[:verdict] == 'helped' }, hurt: rows.count { |r| r[:verdict] == 'hurt' },
      same: rows.count { |r| r[:verdict] == 'same' } }
  end

  def entries
    index! unless @entries
    @entries
  end

  # Highest score first; ties keep people.json order so results are stable.
  def rank(vector, field)
    entries.each_with_index
           .map { |entry, i| [entry, self.class.cosine(vector, entry[field]), i] }
           .sort_by { |_entry, score, i| [-score, i] }
           .map { |entry, score, _i| [entry, score] }
  end

  def build_index
    @people.map do |person|
      enrichment = enrichment_for(person['bio'])
      {
        'name' => person['name'],
        'bio' => person['bio'],
        'enrichment' => enrichment,
        'vector' => @embedder.embedding("#{person['bio']}\n#{enrichment}"),
        'bare_vector' => @embedder.embedding(person['bio'])
      }
    end
  end

  # The prompt asks for markdown, which parse_completion returns as :content.
  # A model that answers in JSON yields a parsed hash instead; keep it as text.
  def enrichment_for(bio)
    result = @expander.search(bio)
    result[:content] || result.to_h.to_json
  end

  def load_cache
    return unless File.exist?(@cache_path)

    data = JSON.parse(File.read(@cache_path))
    data['entries'] if data['people_digest'] == people_digest
  rescue JSON::ParserError
    nil
  end

  def write_cache(entries)
    FileUtils.mkdir_p(File.dirname(@cache_path))
    File.write(@cache_path, JSON.generate('people_digest' => people_digest, 'entries' => entries))
  end

  def people_digest
    Digest::SHA256.hexdigest(JSON.generate(@people))
  end
end
