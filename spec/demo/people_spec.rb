RSpec.describe 'demo/people.json and demo/queries.json' do
  let(:people) { JSON.parse(File.read(File.expand_path('../../demo/people.json', __dir__))) }
  let(:queries) { JSON.parse(File.read(File.expand_path('../../demo/queries.json', __dir__))) }
  let(:text) { people.flat_map(&:values).join("\n") }
  let(:stopwords) do
    %w[with that this from have been they them their there what when where which while who whom would could should
       about into some someone anyone want wants need needs looking like just really help learn find good best more
       most very also than then your mine ours here over does doing]
  end

  # Meaningful words: lowercase letters only, at least 4 long, not a stopword.
  def words(text)
    text.downcase.scan(/[a-z]+/).select { |w| w.length >= 4 } - stopwords
  end

  # Two words clash when their first 5 letters match, which catches defend/defense.
  def stems(text)
    words(text).map { |w| w[0, 5] }.uniq
  end

  it 'holds 25 to 40 people with a name and a bio' do
    expect(people.size).to be_between(25, 40)
    expect(people).to all(match('name' => a_kind_of(String), 'bio' => a_kind_of(String)))
  end

  it('has unique names') { expect(people.map { |p| p['name'] }.uniq.size).to eq(people.size) }

  it 'contains no email addresses' do
    expect(text).not_to match(/[\w.+-]+@[\w-]+\.[\w.]+/)
  end

  it 'contains no phone numbers' do
    expect(text).not_to match(/\+?\d[\d\s().-]{6,}\d/)
  end

  it 'gives every query text, at least one expected person, and a known difficulty' do
    expect(queries).to all(match('query' => a_kind_of(String), 'expect' => a_kind_of(Array),
                                 'difficulty' => a_string_matching(/\A(easy|medium|hard)\z/)))
    expect(queries.map { |q| q['expect'] }).to all(satisfy(&:any?))
  end

  it 'only expects people who exist' do
    names = people.map { |p| p['name'] }
    expect(queries.flat_map { |q| q['expect'] } - names).to be_empty
  end

  it 'keeps a mix of at least 5 hard, 3 medium and 2 easy queries' do
    counts = queries.map { |q| q['difficulty'] }.tally
    expect(counts.fetch('hard', 0)).to be >= 5
    expect(counts.fetch('medium', 0)).to be >= 3
    expect(counts.fetch('easy', 0)).to be >= 2
  end

  it 'makes hard queries share no meaningful word with the bios they expect' do
    bios = people.to_h { |p| [p['name'], p['bio']] }
    queries.select { |q| q['difficulty'] == 'hard' }.each do |q|
      clashes = q['expect'].flat_map { |name| stems(q['query']) & stems(bios.fetch(name)) }
      expect(clashes).to be_empty, "#{q['query'].inspect} shares #{clashes.uniq.inspect} with its expected bios"
    end
  end
end
