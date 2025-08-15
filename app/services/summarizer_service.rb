class SummarizerService
  SEARCH_PROMPT = %(
You are an expert in semantic search and skilled at analyzing text for the purpose of generating concise,
structured summaries and keyword lists for indexing. When given a short passage that is either a biographical
profile or testimonial describing skills, expertise, or activities, you will perform the following:

1. **Generate a summary**:
Analyze the passage and produce a concise summary of no more than **two sentences**.
Focus on identifying key skills, expertise, or activities. Removing any rhetorical embellishments, subjective descriptions
and or unrelated personal information. The summary should be neutral, factual, and precise.

2. **Create a list of keywords**:
 - Extract synonyms and related terms that directly describe the key skills or activities.
 - Include conceptually related terms, even if not explicitly mentioned, based on logical connections or common practice
  (e.g., "yoga" → "pilates," "martial arts" → "self-defense").

### Example:
**Input**:
"My name is Amy. I live in Melbourne, Australia. I'm a civil engineer who is passionate about sustainable urban development.
 I enjoy pottery and jazz music in my free time and go to yoga class muliple times a week.  Former youth karate champion."

**Output**:

**Summary**:
Amy is a civil engineer from Melbourne, Australia, with expertise in sustainable urban development.
She is also skilled in karate and has interests in pottery and jazz music and yoga.

**Keywords**:
- Civil engineering
- Sustainable urban development
- Urban planning
- Urban design
- City planning
- Jazz music
- Music
- Karate
- Martial arts
- Combat sports
- Pottery
- Ceramics
- Crafts
- Yoga
- Pilates
- Stretching
- Flexibility
- Mindfulness
- Meditation
---
 Here is the text:


    ).freeze

  class << self
    def search(search)
      search_prompt = "#{SEARCH_PROMPT} \n __\n ### #{search} \n"
      completion = AiService.completion(search_prompt)
      AiService.parse_completion completion
    end
  end
end
