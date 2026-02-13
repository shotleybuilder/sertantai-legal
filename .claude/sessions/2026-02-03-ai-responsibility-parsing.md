# AI-Enhanced Responsibility Parsing

**Planned**: 2026-02-03
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/17
**Prerequisites**: 2026-02-02-taxa-parser-responsibilities.md

## Background

The regex-based parser has been improved significantly but is reaching its limits:
- Legal text has regularity (modal verbs, actor patterns) but high variation
- Edge cases require increasingly complex patterns
- False positives require post-hoc filtering logic
- Multiple passes needed: detection, extraction, refinement, deduplication

**Current Pipeline:**
```
Regex Detection -> Capture Groups -> ClauseRefiner -> Deduplication -> Output
```

**Proposed Enhancement:**
```
Regex Detection -> AI Extraction/Refinement -> Structured Output -> Validation
```

---

## Option 1: Hybrid Regex + Local LLM

### Architecture

```
Stage 1: Pattern Detection (Current - Keep)
- Regex finds "shall/must/may" with actor patterns
- Identifies candidate paragraphs
- Fast, zero cost

Stage 2: LLM Extraction (New)
- Send candidate paragraph to local LLM
- Structured output: { holder, obligation, conditions }
- Replaces ClauseRefiner complexity
```

### Recommended Local Models

| Model | VRAM (Q4) | Speed | Quality | Best For |
|-------|-----------|-------|---------|----------|
| **Mistral 7B** | 4-6 GB | 30-40 tok/s | Good | General extraction |
| **Phi-3 Mini** | 2-4 GB | Fast | Good | Simple extraction |
| **Phi-4 14B** | 8-10 GB | Medium | Excellent | Complex reasoning |
| **Qwen 2.5 7B** | 4-6 GB | 30-40 tok/s | Good | JSON output |

### Hardware Requirements

**Minimum (Development):**
- 16 GB RAM, any modern CPU
- Ollama with Phi-3 Mini or Mistral 7B (Q4)
- Speed: 5-15 tokens/second (CPU-only)

**Recommended (Production):**
- RTX 3060 12GB (~$250-400 used)
- Mistral 7B or Phi-4 at Q4
- Speed: 30-50 tokens/second

**Mac Alternative:**
- M1/M2/M3 with 16GB+ unified memory
- Mistral 7B: ~28 tokens/second

### Implementation with Ollama

```elixir
# HTTP call to local Ollama
defmodule SertantaiLegal.AI.ResponsibilityExtractor do
  @ollama_url "http://localhost:11434/api/generate"
  
  def extract(candidate_text, actor_hint) do
    prompt = """
    Extract the legal responsibility from this UK legislation text.
    
    Text: #{candidate_text}
    
    Actor hint: #{actor_hint}
    
    Return JSON with:
    - duty_holder: The entity with the obligation
    - obligation: What they must/shall do (complete sentence)
    - conditions: Any conditions or timeframes (list)
    - confidence: high/medium/low
    """
    
    {:ok, response} = Req.post(@ollama_url,
      json: %{
        model: "mistral",
        prompt: prompt,
        format: "json",
        stream: false
      }
    )
    
    Jason.decode!(response.body["response"])
  end
end
```

### Estimated Processing Time

For 19,000 UK LRT records (assuming 2 candidate sections per record average):

| Hardware | Time | Cost |
|----------|------|------|
| CPU only (laptop) | ~24-48 hours | $0 |
| RTX 3060 | ~6-8 hours | $0 |
| M2 Mac 16GB | ~10-14 hours | $0 |

---

## Option 2: Cloud GPU (RunPod/Modal)

### When to Use

- Batch processing large corpus
- Need larger models (70B) for complex documents
- Don't want to maintain local GPU infrastructure

### RunPod Pricing

| GPU | On-Demand | Spot | Use Case |
|-----|-----------|------|----------|
| RTX 4090 | $0.34/hr | ~$0.20/hr | 7B-14B models |
| A100 80GB | $2.17/hr | $1.05/hr | 70B models |

### Modal Pricing

- A10G: $1.10/hr (~$0.0003/second)
- **Scales to zero** - only pay for compute time
- $30/month free credits

### Cost Estimate for UK LRT Corpus

| Provider | Config | Time | Cost |
|----------|--------|------|------|
| RunPod RTX 4090 (spot) | Mistral 7B | 6 hours | ~$1.20 |
| Modal A10G | Mistral 7B | 8 hours | ~$8.80 (or free) |

### Implementation with RunPod Serverless

```elixir
defmodule SertantaiLegal.AI.RunPodClient do
  @endpoint_id System.get_env("RUNPOD_ENDPOINT_ID")
  @api_key System.get_env("RUNPOD_API_KEY")
  
  def extract_batch(texts) do
    Req.post!(
      "https://api.runpod.ai/v2/#{@endpoint_id}/runsync",
      json: %{input: %{texts: texts, task: "responsibility_extraction"}},
      headers: [{"Authorization", "Bearer #{@api_key}"}],
      receive_timeout: 120_000
    )
  end
end
```

---

## Option 3: Bumblebee + LEGAL-BERT (NER)

### Use Case

Named Entity Recognition for duty holders, without full LLM:
- Extract: "planning authority", "Scottish Ministers", "employer"
- Classify: duty holder, power holder, rights holder
- Fast, runs locally, no GPU required

### Implementation

```elixir
# mix.exs
{:bumblebee, "~> 0.6.0"},
{:exla, "~> 0.9.0"}

# Application startup
defmodule SertantaiLegal.Application do
  def start(_type, _args) do
    children = [
      {Nx.Serving, serving: legal_ner_serving(), name: LegalNER}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
  
  defp legal_ner_serving do
    {:ok, model} = Bumblebee.load_model({:hf, "nlpaueb/legal-bert-base-uncased"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "bert-base-uncased"})
    Bumblebee.Text.token_classification(model, tokenizer)
  end
end

# Usage
def extract_entities(text) do
  Nx.Serving.batched_run(LegalNER, text)
end
```

### Limitations

- LEGAL-BERT is for NER/classification, not generative extraction
- Would still need regex or LLM for the actual clause text
- Best as a pre-filter or entity extraction layer

---

## Option 4: Full Hybrid Pipeline

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: Regex Detection (Current - Keep)                   │
│ - Find modal verbs with actor patterns                      │
│ - Extract candidate paragraphs (200-500 chars)              │
│ - Fast, deterministic, zero cost                            │
└─────────────────────────┬───────────────────────────────────┘
                          │ Candidates
┌─────────────────────────▼───────────────────────────────────┐
│ Stage 2: LEGAL-BERT Classification (Optional)               │
│ - Bumblebee + legal-bert-base-uncased                       │
│ - Classify: responsibility / power / right / other          │
│ - Filter low-confidence candidates                          │
│ - Speed: ~100 classifications/second                        │
└─────────────────────────┬───────────────────────────────────┘
                          │ Filtered candidates
┌─────────────────────────▼───────────────────────────────────┐
│ Stage 3: LLM Extraction (Local Ollama or Cloud)             │
│ - Mistral 7B with JSON structured output                    │
│ - Extract: holder, obligation text, conditions              │
│ - Speed: 1-3 seconds per extraction                         │
└─────────────────────────┬───────────────────────────────────┘
                          │ Structured data
┌─────────────────────────▼───────────────────────────────────┐
│ Stage 4: Validation & Deduplication                         │
│ - Schema validation (holder required, obligation required)  │
│ - Deduplicate by semantic similarity                        │
│ - Store in database                                         │
└─────────────────────────────────────────────────────────────┘
```

### Why This Works

1. **Regex** handles the 90% case efficiently
2. **LEGAL-BERT** filters noise before expensive LLM calls
3. **LLM** handles the complex extraction with natural language understanding
4. **Validation** ensures output quality

### Cost Breakdown (19,000 records)

| Stage | Records | Time | Cost |
|-------|---------|------|------|
| Regex | 19,000 | ~2 min | $0 |
| BERT filter | 19,000 | ~3 min | $0 |
| LLM extract | ~5,000 (filtered) | ~4 hrs | $0 (local) |

---

## Structured Output Schema

### JSON Schema for Extraction

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["duty_holder", "obligation"],
  "properties": {
    "duty_holder": {
      "type": "string",
      "description": "The entity with the legal obligation"
    },
    "holder_type": {
      "type": "string",
      "enum": ["government", "authority", "minister", "agency", "organization", "individual"]
    },
    "obligation": {
      "type": "string",
      "description": "Complete sentence describing what they must do"
    },
    "modal_verb": {
      "type": "string",
      "enum": ["must", "shall", "may", "may not"]
    },
    "conditions": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Timeframes, prerequisites, or conditions"
    },
    "confidence": {
      "type": "string",
      "enum": ["high", "medium", "low"]
    }
  }
}
```

### Ollama JSON Mode

```bash
# With Ollama, request structured output
curl http://localhost:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "Extract responsibility from: The planning authority must...",
  "format": "json",
  "options": {"temperature": 0.1}
}'
```

---

## Recommendations

### For Immediate Improvement (Low Effort)

1. **Install Ollama locally** with Mistral 7B
2. **Add fallback to ClauseRefiner** - if regex refinement looks poor, call LLM
3. **Structured output** for consistent extraction

### For Production Quality (Medium Effort)

1. **Full hybrid pipeline** (regex -> optional BERT -> LLM)
2. **Batch processing** with GenServer queue
3. **Quality metrics** to compare regex vs AI extraction

### For Scale (Higher Effort)

1. **RunPod serverless endpoint** for burst capacity
2. **Fine-tune** Mistral on UK legal corpus for better accuracy
3. **Semantic deduplication** using embeddings

---

## Todo

- [ ] Install Ollama and test Mistral 7B locally
- [ ] Create `AI.ResponsibilityExtractor` module
- [ ] Add structured output schema
- [ ] Benchmark: regex-only vs hybrid pipeline
- [ ] Test on UK_ssi_2015_181 corpus
- [ ] Evaluate quality improvement vs processing time
- [ ] Consider LEGAL-BERT for pre-filtering

---

## Resources

### Local LLM
- [Ollama](https://ollama.com/) - Local LLM server
- [Mistral 7B](https://ollama.com/library/mistral) - Best 7B for structured tasks
- [Phi-4](https://ollama.com/library/phi4) - Microsoft's reasoning model

### Cloud GPU
- [RunPod](https://www.runpod.io/) - Cheap GPU cloud, spot instances
- [Modal](https://modal.com/) - Scale to zero, $30/month free

### Elixir ML
- [Bumblebee](https://github.com/elixir-nx/bumblebee) - Native Elixir ML
- [Nx](https://github.com/elixir-nx/nx) - Numerical computing
- [EXLA](https://github.com/elixir-nx/nx/tree/main/exla) - XLA backend for GPU

### Legal NLP
- [LEGAL-BERT](https://huggingface.co/nlpaueb/legal-bert-base-uncased) - Legal text pre-trained
- [Cambridge Law Corpus](https://arxiv.org/html/2309.12269v4) - UK case law dataset

---

## Notes

This session document is for a future spike to evaluate AI-enhanced parsing.
The current regex pipeline works but has diminishing returns on complexity.
AI extraction could handle edge cases that are impractical to cover with regex patterns.
