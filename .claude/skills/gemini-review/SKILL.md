---
name: gemini-review
description: Send a document to Google Gemini for an outside review — free-form, or against one standard in .claude/review-standards/ with --standard (design, naive-reader, plan, zoom-out). Gemini sees the document only, no code.
---

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

The skill takes these inputs:
1. **File path** — the document to review (typically a `.md` plan file)
2. **`--standard <name>`** (optional) — review against `.claude/review-standards/<name>.md`; see "Standard review" below
3. **Review prompt** (optional, ignored with `--standard`) — what to ask Gemini; defaults to the general review prompt

**Gemini sees the document only.** It can't search code, so it can't check reuse or claims about the code. For those use the `reviewer` subagent (`.claude/agents/reviewer.md`). Gemini suits `design` and `naive-reader`, and gives a second model's view on `plan`.

### Saving

Save every review to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard or "gemini">-gemini.md` (e.g. `2026-10-24-review-practices-design-gemini.md`). Re-runs add `-r2`, `-r3`; never overwrite. The folder sits under the ignored `data/`, so commit reviews with `git add -f`. Record triage in the session doc under Taken / Contested (see `.claude/review-standards/README.md`).

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

**IMPORTANT — avoiding truncation:**
- Always include a word limit in the review prompt (e.g. "Keep your response under 1200 words")
- The word limit should be ~60% of `maxOutputTokens / 1.3` to leave margin
  (8192 tokens ≈ 6300 words max → aim for ≤ 1500 words in the prompt instruction)
- Check `finishReason` in the response — if it's `MAX_TOKENS`, the response was truncated

```bash
# Combine the review prompt and document into one string
COMBINED_TEXT="${REVIEW_PROMPT}

---

${DOCUMENT_CONTENT}"

# Build payload — use --arg to safely escape all content
jq -n \
  --arg text "$COMBINED_TEXT" \
  '{
    "contents": [{
      "parts": [{
        "text": $text
      }]
    }],
    "generationConfig": {
      "temperature": 0.7,
      "maxOutputTokens": 8192
    }
  }' | curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d @- > /tmp/gemini-review.json
```

### Step 4: Check for truncation and extract the response

```bash
# Check finish reason FIRST
FINISH=$(jq -r '.candidates[0].finishReason' /tmp/gemini-review.json)
if [ "$FINISH" = "MAX_TOKENS" ]; then
  echo "WARNING: Response was truncated. Retry with a tighter word limit in the prompt."
fi

# Extract text
jq -r '.candidates[0].content.parts[0].text' /tmp/gemini-review.json
```

If truncated, retry with a stricter word limit in the prompt (e.g. "under 800 words")
rather than increasing `maxOutputTokens` (which burns prepaid credits faster).

### Step 5: Present findings

Present Gemini's feedback to the user. If Gemini answered open questions, highlight
those answers. If it found issues, summarise them.

## Standard review (`--standard <name>`)

Build the prompt from files, in this order. Use `gemini-2.5-pro`, `maxOutputTokens` 8192.

```bash
STD=.claude/review-standards/${STANDARD}.md
FORMAT=$(sed -n '/^## Shared output format/,/^## Triage/p' .claude/review-standards/README.md | sed '$d')
REVIEW_PROMPT="You are reviewing a document from sertantai-legal, the admin data workbench of SertantAI: it scrapes and parses UK legislation, extracts definitions and amendments, enriches and quality-checks the data, and pushes reference data to the customer-facing service.
Review the document below against this standard only. Report findings only, in the output format given. Under 900 words.

$(cat "$STD")

${FORMAT}"
```

Then send `REVIEW_PROMPT` + `---` + the document as in Step 3, with `MODEL="gemini-2.5-pro"`.

## Default Review Prompt Template

When no specific prompt and no standard is given, use:

```
You are reviewing a technical plan/design document for sertantai-legal, the
admin data workbench of SertantAI. It scrapes and parses UK legislation, extracts
definitions and amendments, enriches and quality-checks the data, and pushes
reference data to the customer-facing service (sertantai-compliance).

Please:
1. Answer any "Open Questions" in the document with concrete recommendations
2. Identify any gaps, missing scenarios, or edge cases
3. Flag any design decisions you'd challenge or improve
4. Note what's done well
5. Keep your review actionable and specific — no generic praise

Be direct and opinionated. We want a real review, not a rubber stamp.
Keep your response under 1200 words.
```

## Prompt Engineering for Reliable Responses

**Always include a word limit.** Gemini will respect explicit word limits in the prompt
far more reliably than relying on `maxOutputTokens` alone. Rules of thumb:

| Review type | Word limit | maxOutputTokens |
|-------------|-----------|-----------------|
| Quick opinion / pick one option | 800 words | 4096 |
| Standard review with recommendations | 1200 words | 8192 |
| Deep review answering multiple questions | 1500 words | 8192 |

**Keep the review prompt concise.** Long preambles eat into the response budget.
State context in 2-3 sentences, then give numbered instructions.

**Ask for structured output.** "Answer as numbered points" or "Use H2 headings"
produces tighter responses than open-ended "please review".

## Error Handling

- If `GEMINI_API_KEY` is not set: remind user to `source ~/.bashrc` or set the key
- If API returns error: check quota, model name, key validity
- If `finishReason` is `MAX_TOKENS`: response was truncated — retry with tighter word limit
- If `finishReason` is `SAFETY`: content was filtered — rephrase the prompt
- If response is `null`: check `.error` in the JSON for API errors (quota, billing, etc.)

## Notes

- Uses Gemini 2.5 Flash by default (fast, cheap, good reasoning)
- For deeper review, switch to `gemini-2.5-pro`
- The `jq --arg` approach safely escapes all markdown in the document
- Do NOT use jq `++` operator for string concatenation — it doesn't exist in jq
- Response is plain text (Gemini returns markdown)
- Prepaid credits are finite — tighter prompts = less waste on truncated retries
