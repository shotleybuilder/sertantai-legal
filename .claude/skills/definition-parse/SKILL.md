---
name: Definition Parse
description: Parse definitions for a set of laws — wraps mix definitions.backfill and direct Tidewave calls for targeted re-parsing.
user_invocable: true
---

# Definition Parse

Parse definitions from legislation body XML and persist to `legislative_definitions`. Works via `mix definitions.backfill` for batch operations or direct Tidewave calls for individual laws.

## Arguments

`$ARGUMENTS` — scope for parsing. Accepts:

| Input | Interpretation |
|-------|---------------|
| `OH&S` | All unparsed making laws in the OH&S family |
| `UK_ukpga_1974_37` | Single law by name |
| `missing-parents` | Parse laws listed in `data/root_resolver_missing_parents.txt` |
| `unparsed` | All unparsed making laws (default) |
| A file path | Read law names from file (one per line) |

## Steps

### 1. Pre-flight check

Show current parsing coverage for the target scope:

```elixir
# Via Tidewave project_eval
import Ecto.Query
alias SertantaiLegal.Repo

# Family-scoped example (adjust WHERE for other scopes)
Repo.all(
  from lr in "legal_register",
    where: like(lr.family, ^"%OH&S%") and lr.is_making == true
      and lr.live != "❌ Revoked / Repealed / Abolished",
    select: %{
      total: count(),
      parsed: count(lr.definitions_parsed_at),
      unparsed: fragment("COUNT(*) FILTER (WHERE ? IS NULL)", lr.definitions_parsed_at)
    }
)
```

Report: "{parsed}/{total} laws parsed ({unparsed} remaining)". Confirm with user before proceeding.

### 2. Dry-run first

Always preview what will be parsed:

```elixir
# Via Tidewave project_eval — dry-run to list target laws
import Ecto.Query
alias SertantaiLegal.Repo

Repo.all(
  from lr in "legal_register",
    where: like(lr.family, ^"%OH&S%") and lr.is_making == true
      and lr.live != "❌ Revoked / Repealed / Abolished"
      and is_nil(lr.definitions_parsed_at),
    select: %{name: lr.name, title: lr.title_en},
    limit: 50
)
```

Show the list. Confirm with user: "Parse these {N} laws?"

### 3. Parse definitions

**For batch operations** (family/scope):

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend && \
  mix definitions.backfill --scope unparsed --family "OH&S" --limit 50
```

**For single laws** (via Tidewave — faster, no app startup):

```elixir
alias SertantaiLegal.Scraper.{DefinitionParser, DefinitionPersister, LegislationGovUk.Client}

law_name = "UK_ukpga_1974_37"
path = law_name |> String.replace_prefix("UK_", "") |> String.replace("_", "/")

{:ok, xml} = Client.fetch_xml("/#{path}/body/data.xml")
defs = DefinitionParser.parse(xml, %{law_name: law_name, type_code: "ukpga"})

IO.puts("#{length(defs)} definitions found")

if defs != [] do
  {:ok, result} = DefinitionPersister.persist(defs, law_name)
  IO.puts("Upserted: #{result.upserted}")
end

# Mark as parsed
SertantaiLegal.Repo.query(
  "UPDATE legal_register SET definitions_parsed_at = NOW() WHERE name = $1",
  [law_name]
)
```

**For missing parents** (from resolver output):

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend && \
  mix definitions.backfill --file data/root_resolver_missing_parents.txt --force
```

### 4. Report and next step

Show parse results: "{N} laws parsed, {M} definitions upserted".

Always recommend: **"Run `/definition-resolve` to link cross-references."**

## Related Skills

- [Definition Resolve](/definition-resolve) — Link cross-references after parsing
- [Definition QA](/definition-qa) — Full orchestrated workflow
- [LRT Parse Law](/lrt-parse-law) — Parse law metadata (not just definitions)
