# SKILL: Gemini Review

**Purpose:** Send a document or plan to Google Gemini for external review and feedback

**When to Use:**
- Getting a second opinion on a plan or design document
- Asking Gemini to answer open questions in a plan
- Cross-validating architectural decisions
- Any time you want external AI review of project artifacts

---

## How It Works

Uses the Gemini API via `GEMINI_API_KEY` environment variable (set in user's `.bashrc`).
Sends document content with a review prompt via curl to the Gemini REST API.

## Usage

The skill takes two inputs:
1. **File path** — the document to review (typically a `.md` plan file)
2. **Review prompt** — what to ask Gemini (optional, defaults to general review)

### Step 1: Read the document

Read the file to be reviewed.

### Step 2: Build the API request

```bash
# Gemini 2.5 Flash — fast, capable, good for review tasks
MODEL="gemini-2.5-flash"
API_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}"
```

### Step 3: Send to Gemini

Build a JSON payload with the document content and review prompt, then POST to the API.

```bash
# Build payload with jq to handle escaping
jq -n \
  --arg prompt "$REVIEW_PROMPT" \
  --arg doc "$DOCUMENT_CONTENT" \
  '{
    "contents": [{
      "parts": [{
        "text": ($prompt ++ "\n\n---\n\n" ++ $doc)
      }]
    }],
    "generationConfig": {
      "temperature": 0.7,
      "maxOutputTokens": 8192
    }
  }' | curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d @-
```

### Step 4: Extract the response

```bash
# Extract text from Gemini response
jq -r '.candidates[0].content.parts[0].text' response.json
```

### Step 5: Present findings

Present Gemini's feedback to the user. If Gemini answered open questions, highlight those answers. If it found issues, summarise them.

## Default Review Prompt Template

When no specific prompt is given, use:

```
You are reviewing a technical plan/design document for a legal compliance SaaS platform (SertantAI).
The platform helps organisations track which UK laws apply to them, screen new laws, and sync their
legal register to tools like Baserow.

Please:
1. Answer any "Open Questions" in the document with concrete recommendations
2. Identify any gaps, missing scenarios, or edge cases
3. Flag any design decisions you'd challenge or improve
4. Note what's done well
5. Keep your review actionable and specific — no generic praise

Be direct and opinionated. We want a real review, not a rubber stamp.
```

## Error Handling

- If `GEMINI_API_KEY` is not set: remind user to `source ~/.bashrc` or set the key
- If API returns error: check quota, model name, key validity
- If response is too long: Gemini may truncate — increase `maxOutputTokens` or split the document

## Notes

- Uses Gemini 2.5 Flash by default (fast, cheap, good reasoning)
- For deeper review, switch to `gemini-2.5-pro`
- The `jq` payload builder handles all markdown escaping safely
- Response is plain text (Gemini returns markdown)
