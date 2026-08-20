---
name: Definition QA
description: Orchestrate the full definition parsing, resolution, diagnostic, and bug investigation workflow for a family or set of laws.
user_invocable: true
---

# Definition QA

Orchestrate the full definition quality workflow: parse, resolve, diagnose, investigate, log bugs. Enforces session discipline and prevents the circular debugging that happens when steps are skipped or mixed.

## Core Rule

**Investigation sessions find bugs. Fix sessions fix bugs. Never mix the two.**

Mixing investigation and fixing degrades both — context switching between pattern recognition and implementation loses focus in both directions.

## Arguments

`$ARGUMENTS` — scope and mode:

| Input | Interpretation |
|-------|---------------|
| `OH&S` | Investigate OH&S family definitions |
| `fix` | Start a bug fix session |
| `fix CitationExtractor` | Fix bugs in a specific module |
| `UK_ukpga_1974_37` | Investigate a specific law |
| (empty) | Prompted for scope |

## Workflow

```
0. SETUP              Determine session type (investigate vs fix)
       ↓
1. SCOPE              Choose family or law set
       ↓
2. BUGS CHECK         Query existing open bugs (avoid rediscovery)
       ↓
=== Investigation Path ===                    === Fix Path ===
3.  PARSE              /definition-parse      3f. PICK BUGS     Choose bugs to fix
       ↓                                             ↓
4.  RESOLVE            /definition-resolve    4f. FIX            Implement + test
       ↓                                             ↓
5.  MISSING PARENTS    Parse → resolve loop   5f. VERIFY         Re-parse, resolve, diagnose
       ↓                                             ↓
6.  DIAGNOSE           /definition-diagnose   6f. MARK FIXED     Log status: fixed
       ↓                                             ↓
7.  INVESTIGATE        Drill into categories  7f. CLOSE          Close + rebuild index
       ↓
8.  LOG BUGS           Record in frontmatter
       ↓
9.  CLOSE              Close + rebuild index
```

---

## Stage 0: SETUP

Determine the session type from arguments:
- If `$ARGUMENTS` contains "fix" → **Fix path** (stages 2, 3f-7f)
- Otherwise → **Investigation path** (stages 1-9)

Open a session using `/session-start`:
- Investigation: `definition-investigation-{family}-{date}`
- Fix: `definition-fixes-{module}-{date}`

## Stage 1: SCOPE

Determine the target family or law set. Show families with unparsed definitions:

```elixir
# Via Tidewave project_eval
import Ecto.Query
alias SertantaiLegal.Repo

Repo.all(
  from lr in "legal_register",
    where: lr.is_making == true
      and lr.live != "❌ Revoked / Repealed / Abolished",
    group_by: lr.family,
    having: fragment("COUNT(*) FILTER (WHERE ? IS NULL) > 0", lr.definitions_parsed_at),
    select: %{
      family: lr.family,
      total: count(),
      parsed: fragment("COUNT(?)", lr.definitions_parsed_at),
      unparsed: fragment("COUNT(*) FILTER (WHERE ? IS NULL)", lr.definitions_parsed_at)
    },
    order_by: [desc: fragment("COUNT(*) FILTER (WHERE ? IS NULL)", lr.definitions_parsed_at)]
)
```

Confirm scope with user.

## Stage 2: BUGS CHECK

**Always run before investigation** to avoid rediscovering known bugs:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, module, affected FROM open_bugs ORDER BY affected DESC;"
```

Present the list. Say: "These **{N} bugs** are already known. During investigation, watch for **new** patterns not in this list."

If the index doesn't exist, build it first:
```bash
/usr/bin/python3 /var/home/jason/Desktop/sertantai-legal/scripts/maintenance/session_index.py \
  --root /var/home/jason/Desktop/sertantai-legal
```

---

## Investigation Path

### Stage 3: PARSE

Run `/definition-parse` for the scoped family:

1. Dry-run to preview which laws will be parsed
2. Confirm with user
3. Parse definitions
4. Report: "{N} laws parsed, {M} definitions upserted"

### Stage 4: RESOLVE

Run `/definition-resolve`:

1. Show pre-check metrics (cross-refs, linked, unlinked)
2. Run `RootResolver.resolve_all()` (or `force: true` if re-parsing)
3. Report results

### Stage 5: MISSING PARENTS LOOP

If resolver found missing parents:

1. Parse missing parents: `/definition-parse missing-parents`
2. Re-resolve: `RootResolver.resolve_all()`
3. Check for new missing parents
4. Repeat until missing parents count stabilises (typically 2-3 iterations)

### Stage 6: DIAGNOSE

Run `/definition-diagnose` for the scoped family:

1. Run diagnostic
2. Display actionable vs ceiling breakdown
3. Record baseline metrics in session doc

### Stage 7: INVESTIGATE

For each **actionable** category (in order of affected count):

1. Sample 5-10 findings
2. Look for patterns: same law, same citation format, same parser behaviour
3. Cross-reference against known bugs from Stage 2
4. For genuinely new patterns: determine corpus-wide affected count, identify responsible module, suggest fix approach

### Stage 8: LOG BUGS

For each new bug discovered:

1. **Dedup check** (mandatory):
   ```bash
   sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
     "SELECT pattern, module, affected FROM bugs WHERE pattern LIKE '%keyword%';"
   ```
2. If no match, add to session frontmatter:
   ```yaml
   bugs:
     - pattern: "Description"
       category: diagnostic_category
       module: ModuleName
       affected: count
       fix: "Suggested approach"
       status: open
   ```

### Stage 9: CLOSE

1. Close session using `/session-close`
2. Rebuild SQLite index:
   ```bash
   /usr/bin/python3 /var/home/jason/Desktop/sertantai-legal/scripts/maintenance/session_index.py \
     --root /var/home/jason/Desktop/sertantai-legal
   ```
3. Verify new bugs appear in the index

---

## Fix Path

### Stage 3f: PICK BUGS

Show open bugs grouped by module (triage view):

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT module, COUNT(*) as bugs, SUM(affected) as total_affected
   FROM open_bugs
   GROUP BY module ORDER BY total_affected DESC;"
```

Then drill into the target module:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, affected, fix
   FROM open_bugs AND module = 'TARGET_MODULE'
   ORDER BY affected DESC;"
```

User picks which bugs to fix in this session.

### Stage 4f: FIX

Implement code changes + tests. Key files by module:

| Module | File |
|--------|------|
| DefinitionParser | `backend/lib/sertantai_legal/scraper/definition_parser.ex` + `definition_parser/` |
| CitationExtractor | `backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex` |
| Matcher | `backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex` |
| Diagnostic | `backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex` |
| Definition (struct) | `backend/lib/sertantai_legal/scraper/definition_parser/definition.ex` |

Run tests after each fix: `mix test test/sertantai_legal/scraper/`

### Stage 5f: VERIFY

After fixing, verify the improvement:

1. Re-parse a representative sample of affected laws
2. Re-resolve with `force: true`
3. Re-run diagnostic for the same family
4. Compare actionable counts against pre-fix baseline
5. Confirm the targeted category count dropped

### Stage 6f: MARK FIXED

Log each fixed bug in the current session's frontmatter:

```yaml
bugs:
  - pattern: "Same description as original"
    category: same_category
    module: SameModule
    affected: updated_count
    fix: "What was actually done"
    status: fixed
```

### Stage 7f: CLOSE

Same as Stage 9 — close session and rebuild index.

---

## Guardrails

These are enforced throughout — not suggestions:

1. **Never parse without resolving afterward** — parsing changes definitions, resolver must re-link
2. **Never resolve without diagnosing afterward** — resolution changes links, diagnostic must reclassify
3. **Never fix bugs in an investigation session** — log them and start a separate fix session
4. **Always check existing bugs before logging** — prevents duplicate bug entries
5. **Always rebuild SQLite index after closing** — keeps bug queries current
6. **Use `live` status to filter revoked parents** — don't chase phantoms

## Related Skills

- [Definition Parse](/definition-parse) — Parse definitions (stage 3)
- [Definition Resolve](/definition-resolve) — Link cross-references (stage 4)
- [Definition Diagnose](/definition-diagnose) — Classify failures (stage 6)
- [Definition Bugs](/definition-bugs) — Bug backlog management (stage 2, 8)
- [Session Start](/session-start) — Open a session (stage 0)
- [Session Close](/session-close) — Close a session (stage 9)
