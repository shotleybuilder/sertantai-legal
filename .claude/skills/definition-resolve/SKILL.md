---
name: Definition Resolve
description: Run the root resolver to link cross-reference definitions to their originating laws.
user_invocable: true
---

# Definition Resolve

Link cross-reference definitions ("has the meaning given in the Scotland Act 1998") to their root definitions in the parent law. Wraps `RootResolver.resolve_all/1`.

## Arguments

`$ARGUMENTS` — optional mode:

| Input | Interpretation |
|-------|---------------|
| (empty) | Incremental — only unlinked cross-refs |
| `force` | Full re-resolve — all cross-refs including already-linked |
| `dry-run` | Preview — show results without writing to DB |

Use `force` after parser fixes or stale data cleanup. Use `dry-run` to preview impact.

## Steps

### 1. Pre-check current state

Show current resolution metrics:

```elixir
# Via Tidewave project_eval
import Ecto.Query
alias SertantaiLegal.Repo

result = Repo.one(
  from d in "legislative_definitions",
    select: %{
      cross_refs: count() |> filter(d.references_other_law == true and d.citation == false),
      linked: fragment("""
        COUNT(*) FILTER (WHERE ? = true AND ? = false
          AND EXISTS (SELECT 1 FROM definition_links dl WHERE dl.child_definition_id = ?))
        """, d.references_other_law, d.citation, d.id),
      unlinked: fragment("""
        COUNT(*) FILTER (WHERE ? = true AND ? = false
          AND NOT EXISTS (SELECT 1 FROM definition_links dl WHERE dl.child_definition_id = ?))
        """, d.references_other_law, d.citation, d.id)
    }
)

pct = Float.round(100.0 * result.linked / max(result.cross_refs, 1), 1)
IO.puts("Cross-refs: #{result.cross_refs}, Linked: #{result.linked} (#{pct}%), Unlinked: #{result.unlinked}")
```

### 2. Run resolver

```elixir
# Via Tidewave project_eval (timeout: 300000)
opts = [force: true]  # or [] for incremental, [dry_run: true] for preview
{:ok, result} = SertantaiLegal.Scraper.RootResolver.resolve_all(opts)
result
```

### 3. Report results

Display the result map:

| Status | Count | Meaning |
|--------|-------|---------|
| `resolved` | N | Linked to root definitions |
| `citation_only` | N | Citation extracted, parent not parsed or term absent |
| `internal` | N | Internal reference within same law |
| `unresolved` | N | No citation could be extracted |
| `missing_parents` | N | Unique parent laws not yet parsed |

### 4. Handle missing parents

If `missing_parents > 0`:

> "Resolver found **{N} parent laws** that are in the legal register but haven't been parsed for definitions. These are written to `data/root_resolver_missing_parents.txt`."
>
> "Run `/definition-parse missing-parents` to parse them, then re-resolve."

The parse-resolve loop typically stabilises in 2-3 iterations.

### 5. Next step

Always recommend: **"Run `/definition-diagnose` to classify remaining unlinked definitions."**

## Related Skills

- [Definition Parse](/definition-parse) — Parse definitions (run before resolving)
- [Definition Diagnose](/definition-diagnose) — Classify failures (run after resolving)
- [Definition QA](/definition-qa) — Full orchestrated workflow
