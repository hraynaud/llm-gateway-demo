RSpec.describe 'demo/people.json' do
  let(:people) { JSON.parse(File.read(File.expand_path('../../demo/people.json', __dir__))) }
  let(:text) { people.flat_map(&:values).join("\n") }

  it 'holds 15 to 25 people with a name and a bio' do
    expect(people.size).to be_between(15, 25)
    expect(people).to all(match('name' => a_kind_of(String), 'bio' => a_kind_of(String)))
  end

  it 'contains no email addresses' do
    expect(text).not_to match(/[\w.+-]+@[\w-]+\.[\w.]+/)
  end

  it 'contains no phone numbers' do
    expect(text).not_to match(/\+?\d[\d\s().-]{6,}\d/)
  end
end
