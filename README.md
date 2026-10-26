# llm-gateway-demo

This code is extracted from a graph-RAG application I started building in spring 2019, worked on off and on, and committed to finishing in 2024. I launched it in private beta in the summer of 2026, and I'm now revising the rollout based on early feedback and experiments. It's my long-running side project, and the place I try out new ideas and experiment with new technologies and techniques. Adding an inference layer to the app I was already building, and then moving to AI-assisted, spec-driven development (which is how pretty much all the code since mid-2026 has been written), were a perfect fit for both the product goals and my own learning.
    
The app used closed-weight models (OpenAI and Gemini) for chat and completion, and open-weight models such as nomic-embed-text and later mxbai-embed-large, served by Ollama, for embeddings.

The primary datastore is a graph database with nodes for people, topics, endorsements and so on, and the relationships between them. The original idea was much like a personal Angie's List. At a high level, each endorsement carries an embedding of what was said, and a vector index over those embeddings lets a search find relationships by meaning rather than by keyword. A query is matched against the vector index first, and then the graph is walked to show how the person searching is connected to whoever turned up.

I always knew I needed a graph. I considered building one from scratch (years ago I worked on a graph database implementation in Redis), but decided against it and reached for an actual graph database instead. The AI came later, in early 2024, to solve one problem that had nagged me for a long time: matching on meaning instead of exact words. For example, a search like "I'm really into self-defense because I live in a sketchy part of town and work nights. Looking for a capable instructor who's not too expensive and does 1-1 classes" should find judo, martial arts, self-defense, coach, teacher. I considered Elasticsearch, but the ability to match on free-form, narrative, human-written text made going the embedding route a no-brainer. I didn't know about graph RAG and didn't realize that was what I was building. I was just working through the problems I encountered myself, in late 2023 and early 2024, months before graph RAG gained traction as an answer to the limits of plain RAG.

What's in this repo is the AI layer on top of that graph. The graph itself, and other features I consider the app's own IP, are left out.

It's raw HTTP and the Ollama client, with no LangChain:

- **A provider gateway.** `AiService` reads `AI_PROVIDER` and hands every `completion`, `chat`
  and `embedding` call to Ollama, OpenAI or Gemini. Each provider module speaks its own wire
  format, so the callers never know which one answered.
- **Conversational assistants that end in data.** Onboarding and project creation were both
  guided interviews. The assistant asks one question at a time, summarises what it heard, asks
  you to confirm, and then closes with a JSON block inside `<user_data>` or `<project_data>`
  tags that the client turns into a profile or a project form. Each provider has its own
  adapter under a shared base class. I preferred Gemini for these because the conversation
  felt better.
- **Enrichment before embedding.** Short text embeds poorly, so before an endorsement was
  embedded, the LLM expanded its topic into related terms ("yoga" brings in "pilates", "karate"
  brings in "martial arts"), and the endorsement was embedded together with those terms. That
  way a search can match the concept, not just the words someone happened to type. The terms
  are generated once per topic and reused. The graph code that did this isn't included here.
  Search queries were expanded the same way: the LLM routed a free-text query to a canonical
  topic, and that topic's related terms were added to the query before it was embedded.
  `SummarizerService` is a prompt I wrote for the same idea at the profile level. It was never
  wired in, and `bin/search` uses it so you can see the technique run.

```bash
bundle install
bundle exec rspec          # offline, no keys needed
bin/onboard                # needs a local Ollama (see "Run it")
```

## Run it

1. **Specs only.** Ruby 4.0.1 (pinned in `.ruby-version`; the Gemfile allows >= 3.2, which is untested) and `bundle install`; nothing else to install.
2. **Local Ollama (free, no key).** `brew install ollama && ollama serve`, then
   `ollama pull llama3 && ollama pull mxbai-embed-large`. Other models work:
   `LLM=qwen2:7b EMBEDDING_MODEL=nomic-embed-text bin/onboard`.
3. **Hosted provider.** `AI_PROVIDER=gemini GEMINI_API_KEY=… bin/onboard`, or
   `AI_PROVIDER=openai OPENAI_API_KEY=… bin/search --eval`.

Environment variables (all optional for local Ollama):

| Variable | Default | Used for |
|---|---|---|
| `AI_PROVIDER` | `ollama` | `ollama`, `openai` or `gemini` |
| `LLM` | `llama3` | Ollama chat/completion model |
| `EMBEDDING_MODEL` | `mxbai-embed-large` | Ollama embedding model |
| `EMBEDDING_MODEL_PROVIDER` | follows `AI_PROVIDER` if it can embed, otherwise `ollama` | Which provider embeds for `bin/search` (`ollama` or `openai`) |
| `OLLAMA_SERVER_ADDRESS` | `http://localhost:11434` (set by `config/boot.rb`; the service itself defaults to `http://ollama:11434`) | Ollama URL |
| `GEMINI_API_KEY` | none, required for Gemini | Gemini auth |
| `GEMINI_LLM` | `gemini-2.5-flash` | Gemini model |
| `OPENAI_API_KEY` | none, required for OpenAI | OpenAI auth |
| `OPENAI_LLM` | `gpt-5-mini` (the model sent with each request) | OpenAI model |
| `OPENAI_EMBEDDING_MODEL` | `text-embedding-3-small` | OpenAI embeddings |
| `LOG_LEVEL` | `warn` (`bin/chat` uses `debug` unless you set it) | Log verbosity |

| Script | Shows |
|---|---|
| `bin/chat` | An early general chat endpoint that summarises its own history (not part of the flows above) |
| `bin/onboard` | The onboarding interview; prints the extracted `<user_data>` JSON |
| `bin/search QUERY [--compare]` | Enrichment-based search over `demo/people.json`; `--compare` shows each match with and without enrichment |
| `bin/search --eval` | Scores the queries in `demo/queries.json` with and without enrichment |

Smaller local models follow the JSON-in-tags format less reliably than Gemini. `bin/onboard`
tells you when the block isn't valid JSON.

## Swap the models

`bin/search` uses two models with different jobs:

- **The enrichment model** reads each profile and writes a summary plus related terms.
  `AI_PROVIDER` picks it.
- **The embedding model** turns the enriched profiles and your query into vectors.
  `EMBEDDING_MODEL_PROVIDER` picks it.

Mix them freely:

```bash
bin/search "QUERY" --compare                                       # Ollama enriches and embeds
AI_PROVIDER=gemini GEMINI_API_KEY=… bin/search "QUERY" --compare   # Gemini enriches, Ollama embeds
AI_PROVIDER=openai OPENAI_API_KEY=… bin/search --eval              # OpenAI does both
```

Each combination gets its own cached index, and the first line of every run names both models.

**Reading the output.** Strength is how far a person's score sits above the query's average, in
standard deviations (`+2.3σ`). Matches at +1.5σ or more count as strong; the rest go under a
"weaker matches" divider. The cutoff is relative on purpose: each embedding model scores on its
own scale, so a fixed number stops working the moment you swap models. `--compare` shows each
person's rank with and without enrichment, `↑n` or `↓n` when enrichment moved them, and
`<- found via enrichment` only for a strong match the bare bio would have ranked outside the
top 5. `--eval` runs the queries in `demo/queries.json`, each naming the people it should find,
and reports how often the right person came first with and without enrichment.

### What to expect

On my machine, with local models only (12 queries):

| Enrichment | Embeddings | Right person #1, enriched | Right person #1, bare | Enrichment helped / hurt / same |
|---|---|---|---|---|
| qwen2:7b | mxbai-embed-large | 11/12 | 11/12 | 0 / 0 / 12 |
| qwen2:7b | nomic-embed-text | 11/12 | 11/12 | 1 / 0 / 11 |

Two things likely limit the effect with local models. A small model writes weak enrichment: it tends to
restate the bio instead of adding related ideas, and enrichment is only as good as the terms it
adds. And newer embedding models already place related words close together, which closes much
of the gap enrichment was built for. In January 2025 I switched from all-minilm (which had replaced
nomic-embed-text early on) to the larger, higher-dimensional mxbai-embed-large (384 to 1024 dimensions) after the tuning I knew
about didn't help. To compare a stronger enrichment model, set `AI_PROVIDER=gemini` or
`AI_PROVIDER=openai` and run `bin/search --eval` again.

For example, with qwen2:7b and mxbai-embed-large, take the query "my teenager wants to protect
herself if someone grabs her". Rafael Ortiz's bio never uses the query's words, and enrichment
lifts him from 5th to 3rd. He was in the top 5 either way, so he is not marked as found via
enrichment, but he stays above the divider:

```
Enrichment: ollama (qwen2:7b) · Embeddings: ollama (mxbai-embed-large)
name                   enriched        bare       move
Owen Clarke             1 0.568 +3.2σ   1 0.501
Lucía Ferreira          2 0.492 +2.0σ   2 0.477
Rafael Ortiz            3 0.473 +1.7σ   5 0.433   ↑2
Beatrice Moyo           4 0.459 +1.5σ   4 0.439
--- weaker matches (not clearly above the crowd) ---
Hannah Weiss            5 0.457 +1.4σ   3 0.452   ↓2
```

## What's original and what's new

`git log --until=2025-12-31` is the original work, unchanged. Everything after it was added in
2026 with AI assistance, through a spec-driven, test-first process:

- `config/boot.rb`, a small shell that lets the Rails services run as plain Ruby.
- Six fixes to latent bugs in the original code (seven `fix:` commits; one needed a follow-up), each with the spec that caught it, plus five `fix:` commits to the new demo scripts.
- Ollama adapters for the assistants, the `demo/` search, the `bin/` scripts and the test suite.
- For `bin/search`: separate enrichment and embedding models (`EMBEDDING_MODEL_PROVIDER`), a cache per model pair, match strength in standard deviations, a stricter `--compare`, harder demo data and `--eval`.

## What I'd do differently today

I built this on raw HTTP and the Ollama client. I added LangChain's Ruby port (`langchainrb`) to
the Gemfile in February 2024, mainly as a chance to learn it, and took it out a year later without
ever calling it. That wasn't because my own layer had a gap LangChain would have filled. My
implementation already maps onto LangChain's basics: a linear, deterministic chain of chat,
summarizer, embedding and graph search. Building it by hand taught me what these frameworks
abstract away. Knowing what I know now, here's what I'd change:

- **Evaluate from the start.** I changed retrieval strategies more than once, and part of that
  churn came from having no way to measure them. I didn't know that evaluating model output
  against a fixed set of queries and expected answers was standard practice, so I went by what
  looked right and by specs I'd written against dummy data. The similarity cutoff is a good
  example. I filtered vector matches with a fixed minimum score and lowered it three times over
  two years, usually alongside a model change, because each new model scored on its own scale
  and the old cutoff started dropping good matches. I was tuning by feel against a moving target.
  Now that I know, I'd build an evaluation set early, judge every model, prompt or strategy change
  against it, and use a cutoff relative to each query's own scores, which is what the demo does.
- **Port the chain to LangChain to learn it properly.** The flow is simple enough to translate
  step for step, which makes it a good way to compare the framework with code I already
  understand. If the flow ever needed to branch, loop or let the model decide the next step,
  that's where LangGraph would come in.
- **Structured output instead of JSON in tags.** The assistants end with JSON inside
  `<user_data>` tags, and smaller models sometimes break the format. Today OpenAI, Gemini and
  Ollama all accept a JSON schema and return valid JSON. I'd use that and drop the regex.
- **Combine retrieval strategies instead of choosing one.** Over time I used three: vector
  search with the query expanded by its topic's related terms, keyword matching, and having the
  LLM route a query to a canonical topic. Each search used one of them. Today I'd run them
  together, merge the results into one ranked list, and add a reranking step.
- **Tracing.** I'd log every prompt, response, latency and cost, so a bad answer can be traced to
  its cause.

## Known limits

- `app/controllers/` is reference code showing the Rails integration. It needs Rails and is not
  loaded here.
- Server-sent-event streaming (`ChatController#stream`) is not demonstrated.
- Gemini supports completion, enrichment and the assistants, but not embeddings or streaming chat, so it can't be the embedding provider for `bin/search`.
- `GeminiOnboardingAssistant::SYSTEM_INSTRUCTION_BKP` is an unused earlier prompt, kept as history.

## Appendix: timeline from the commit history

Dates and commit messages are from the original history, which is preserved in this repo, so
`git show <commit>` will confirm each row.

| Date | Commit | Commit message | Step |
|---|---|---|---|
| 2024-02-15 | `490151c` | wip_introducing llama | First LLM call: `OllamaService` against a local model |
| 2024-02-24 | `3e83973` | Adds RAG search capability to endorsements search | Embeddings and vector search over endorsements (the search code is not included) |
| 2025-01-10 | `ee0c5dc` | adds topic and summary services | `SummarizerService`: a profile-enrichment prompt, written but never wired in |
| 2025-08-15 | `1036002` | Implements AI provider factory to switch between AI services | `AiService`: Ollama, OpenAI and Gemini behind one interface |
| 2025-08-15 | `87466dc` | adds project and onboarding assitants | The Collabi project and onboarding assistants |
| 2025-09-07 | `8871f4f` | ai onboarding working | AI onboarding working end to end |
