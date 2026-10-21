# llm-gateway-demo

The AI layer I designed and built for a production Rails app (Konmego, branded CollabSphere in 2025)
between February 2024 and December 2025. It covers a multi-provider LLM gateway, chat with
rolling memory, conversational assistants that produce structured output, and LLM-enriched
semantic search. Everything here is built from first principles on raw HTTP and the Ollama
client, with no LangChain.

```bash
bundle install
bundle exec rspec          # offline, no keys needed
bin/onboard                # needs a local Ollama (see "Run it")
```

## How it grew

Dates and commit messages are from the original history, which is preserved here.

| Date | Commit | Commit message | Step |
|---|---|---|---|
| 2024-02-15 | `490151c` | wip_introducing llama | First LLM call: `OllamaService` against a local model |
| 2024-02-24 | `3e83973` | Adds RAG search capability to endorsements search | Embeddings and RAG-style semantic search (the search code is not included) |
| 2025-01-10 | `ee0c5dc` | adds topic and summary services | `SummarizerService`: an LLM prompt that enriches profiles with related terms before indexing |
| 2025-04-19 | `8f9b354` | adds chat to projects | Chat on projects |
| 2025-08-15 | `1036002` | Implements AI provider factory to switch between AI services | `AiService` provider factory: Ollama, OpenAI and Gemini behind one interface |
| 2025-08-15 | `87466dc` | adds project and onboarding assitants | The Collabi project and onboarding assistants |
| 2025-09-07 | `8871f4f` | ai onboarding working | AI onboarding working end to end |

## Design

**Provider gateway.** `AiService` picks a provider from `AI_PROVIDER` (default `ollama`) and
exposes `completion`, `chat`, `embedding` and `parse_completion`. Each provider module adapts
its own wire format: `ollama-ai` for Ollama, and raw `Net::HTTP` for OpenAI and Gemini.
Callers never see which provider is in use.

**Rolling memory.** `ChatService` keeps the conversation. When it grows past
`MAX_HISTORY_SIZE`, the LLM summarises the history, and that summary replaces it as a single
system message. This keeps the context bounded without losing the thread.

**Structured output from conversation.** The Collabi assistants run a guided interview and
finish with a JSON block inside `<user_data>` or `<project_data>` tags, so free conversation
ends in machine-readable data. Each provider has its own adapter (`GeminiAssistant`,
`OpenaiAssistant`, `OllamaAssistant`) under a shared base, and `AiService` picks the one that
matches `AI_PROVIDER`. Gemini was the provider of choice for the assistants because it gave the
best conversational experience.

**Enrichment-based search.** `SummarizerService::SEARCH_PROMPT` rewrites each profile when it
is indexed, adding a neutral summary plus synonyms and related terms ("yoga" brings in
"pilates", "karate" brings in "martial arts"). A plain query vector can then match concepts the
person never wrote down. `bin/search` demonstrates this over invented profiles, and
`--compare` shows who is found only because of the enrichment.

## Run it

1. **Specs only.** Ruby 4.0.1 (pinned in `.ruby-version`; the Gemfile allows >= 3.2, which is untested) and `bundle install`; nothing else to install.
2. **Local Ollama (free, no key).** `brew install ollama && ollama serve`, then
   `ollama pull llama3 && ollama pull mxbai-embed-large`. Other models work:
   `LLM=qwen2:7b EMBEDDING_MODEL=nomic-embed-text bin/chat`.
3. **Hosted provider.** `AI_PROVIDER=gemini GEMINI_API_KEY=… bin/onboard`, or
   `AI_PROVIDER=openai OPENAI_API_KEY=… bin/search "someone into pilates"`.

Environment variables (all optional for local Ollama):

| Variable | Default | Used for |
|---|---|---|
| `AI_PROVIDER` | `ollama` | `ollama`, `openai` or `gemini` |
| `LLM` | `llama3` | Ollama chat/completion model |
| `EMBEDDING_MODEL` | `mxbai-embed-large` | Ollama embedding model |
| `OLLAMA_SERVER_ADDRESS` | `http://localhost:11434` (set by `config/boot.rb`; the service itself defaults to `http://ollama:11434`) | Ollama URL |
| `GEMINI_API_KEY` | none, required for Gemini | Gemini auth |
| `GEMINI_LLM` | `gemini-2.5-flash` | Gemini model |
| `OPENAI_API_KEY` | none, required for OpenAI | OpenAI auth |
| `OPENAI_LLM` | `gpt-5-mini` (the model sent with each request) | OpenAI model |
| `OPENAI_EMBEDDING_MODEL` | `text-embedding-3-small` | OpenAI embeddings |
| `LOG_LEVEL` | `warn` (`bin/chat` uses `debug` unless you set it) | Log verbosity |

| Script | Shows |
|---|---|
| `bin/chat` | Rolling memory; `"[debug] Summary of previous conversation"` lines show each summarisation |
| `bin/onboard` | The onboarding interview; prints the extracted `<user_data>` JSON |
| `bin/search QUERY [--compare]` | Enrichment-based search over `demo/people.json` |

Smaller local models follow the JSON-in-tags format less reliably than Gemini. `bin/onboard`
tells you when the block isn't valid JSON.

## What's original and what's new

`git log --until=2025-12-31` is the original work, unchanged. Everything after it was added in
2026 with AI assistance, following the spec and plan in `docs/`:

- `config/boot.rb`, a small shell that lets the Rails services run as plain Ruby.
- Six fixes to latent bugs (seven `fix:` commits; one needed a follow-up), each with the spec that caught it.
- Ollama adapters for the assistants, the `demo/` search, the `bin/` scripts and the test suite.

## Known limits

- `app/controllers/` is reference code showing the Rails integration. It needs Rails and is not
  loaded here.
- Server-sent-event streaming (`ChatController#stream`) is not demonstrated.
- Gemini supports completion and the assistants, but not embeddings or streaming chat.
- `GeminiOnboardingAssistant::SYSTEM_INSTRUCTION_BKP` is an unused earlier prompt, kept as history.
