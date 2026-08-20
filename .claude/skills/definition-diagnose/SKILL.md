---
name: Definition Diagnose
description: Run the resolution diagnostic to classify unlinked cross-references into failure categories and drill into specific patterns.
user_invocable: true
---

# Definition Diagnose

Classify all unlinked cross-reference definitions into failure categories, separate actionable bugs from structural ceiling, and drill into patterns for bug logging.

## Arguments

`$ARGUMENTS` — optional family filter (e.g. `OH&S`, `FIRE`, `TRANSPORT`).

Family names in the DB use emoji prefixes and full names (e.g. `"💙 OH&S: Occupational / Personal Safety"`). Use `LIKE '%keyword%'` matching, not exact match.

## Steps

### 1. Run diagnostic

```elixir
# Via Tidewave project_eval (timeout: 300000)
alias SertantaiLegal.Scraper.RootResolver.Diagnostic
import Ecto.Query
alias SertantaiLegal.Repo

# Build the OH&S law set (adjust family filter as needed)
family_filter = "%OH&S%"

ohs_laws = Repo.all(
  from lr in "legal_register",
    where: like(lr.family, ^family_filter),
    select: lr.name
) |> MapSet.new()

# Run full diagnostic (the :family option uses exact match which doesn't work with emoji prefixes)
{:ok, all_findings} = Diagnostic.run()
findings = Enum.filter(all_findings, fn f -> MapSet.member?(ohs_laws, f.law_name) end)

summary = Diagnostic.summarise(findings)
Diagnostic.print_summary(summary)
```

For corpus-wide diagnostic (no family filter), just use `Diagnostic.run()` directly without filtering.

### 2. Interpret results

The diagnostic prints:

```
══ Resolution Diagnostic ══
Total unlinked: 243 (211 actionable, 32 ceiling)

Actionable:
  term_not_found              119  (49.0%)
  no_citation                  81  (33.3%)
  parent_unparsed               7  (2.9%)
  term_normalisation            4  (1.6%)

Ceiling (not actionable):
  parent_revoked               23  (9.5%)
  parent_not_in_lrt             9  (3.7%)
```

**Category reference:**

| Category | Meaning | Action |
|----------|---------|--------|
| `term_not_found` | Parent parsed, term absent | Parser bug, HSWA blob, section-level defs |
| `no_citation` | Can't extract citation from text | CitationExtractor regex gaps, or internal ref misclassification |
| `parent_unparsed` | Parent in LRT but defs not parsed | Run `/definition-parse` for these parents |
| `term_normalisation` | Term exists with different spelling | Normalisation bug in `Definition.normalise_term/1` |
| `citation_ambiguous` | Term found but not linked | Multi-law resolution ambiguity |
| `parent_revoked` | Parent law fully revoked | **Ceiling** — not fixable |
| `parent_not_in_lrt` | Parent not in legal register | **Ceiling** — pre-1963 Acts, EU laws, NI instruments |

**Focus investigation on actionable categories only.** Ceiling items are structural limits.

### 3. Drill into a category

When the user wants to investigate a specific category, filter the findings:

```elixir
# Continue from step 1 (findings already in scope)

# Example: drill into no_citation
no_citation = Enum.filter(findings, & &1.category == :no_citation)
IO.puts("#{length(no_citation)} no_citation findings")

# Sample 10 to identify patterns
no_citation
|> Enum.take(10)
|> Enum.each(fn f ->
  def_text = String.slice(f.detail || "", 0, 80)
  IO.puts("  #{f.term} | #{f.law_name} | #{def_text}")
end)
```

For `term_not_found`, the top_parents in the summary shows which parent laws to investigate first.

For `parent_unparsed`, list the unparsed parents:

```elixir
parent_unparsed = Enum.filter(findings, & &1.category == :parent_unparsed)
parent_unparsed
|> Enum.frequencies_by(& &1.target_law)
|> Enum.sort_by(&elem(&1, 1), :desc)
|> Enum.each(fn {law, count} -> IO.puts("  #{law}: #{count} refs") end)
```

### 4. Compare with baseline

If a previous diagnostic exists (check session files for prior metrics), compare:

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Total unlinked | ? | ? | ? |
| term_not_found | ? | ? | ? |
| no_citation | ? | ? | ? |

This tracks progress across sessions. Record the new baseline in the session doc.

### 5. Log bugs or recommend next steps

**Investigation session**: For each new pattern found, check `/definition-bugs` for duplicates, then log in session frontmatter:

```yaml
bugs:
  - pattern: "Description of the pattern"
    category: no_citation
    module: CitationExtractor
    affected: 53
    fix: "Suggested fix approach"
    status: open
```

**Quick fixes available**: If `parent_unparsed > 0`, recommend `/definition-parse` for those parents.

**Never fix bugs in a diagnostic session** — log them and start a separate fix session.

## Related Skills

- [Definition Resolve](/definition-resolve) — Run before diagnosing
- [Definition Bugs](/definition-bugs) — Check existing bugs before logging new ones
- [Definition QA](/definition-qa) — Full orchestrated workflow
