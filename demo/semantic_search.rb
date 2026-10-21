require 'digest'
require 'fileutils'
require 'json'

# Added 2026, clean-room: enrichment-based retrieval built on the original
# SummarizerService prompt. Each profile is enriched once by the LLM (summary
# plus related terms), embedded, and ranked against the raw query by cosine
# similarity. `compare` also ranks the un-enriched bio to show what the
# enrichment buys.
class SemanticSearch
  def self.cache_path_for(provider:, model:, dir: __dir__)
    File.join(dir, ".index-#{"#{provider}-#{model}".gsub(/[^A-Za-z0-9._-]/, '_')}.json")
  end

  def self.cosine(a, b)
    dot = a.zip(b).sum { |x, y| x * y }
    norms = Math.sqrt(a.sum { |x| x * x }) * Math.sqrt(b.sum { |x| x * x })
    norms.zero? ? 0.0 : dot / norms
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
    rank(@embedder.embedding(text), 'vector').first(k).map do |entry, score|
      { name: entry['name'], score:, enrichment: entry['enrichment'] }
    end
  end

  def compare(text, k: 5)
    vector = @embedder.embedding(text)
    bare = rank(vector, 'bare_vector').map(&:first)
    rank(vector, 'vector').first(k).each_with_index.map do |(entry, _score), i|
      bare_rank = bare.index(entry) + 1
      { name: entry['name'], enriched_rank: i + 1, bare_rank:, gained: bare_rank > k }
    end
  end

  private

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
