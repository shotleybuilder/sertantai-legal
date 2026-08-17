---
name: LRT Parse Law
description: Parse one or more laws through the full LRT pipeline (metadata, amendments, definitions) without needing the admin UI.
user_invocable: true
---

# LRT Parse Law

Parse any UK law through the full pipeline — metadata, extent, enacted_by, amendments, definitions — and persist to legal_register + legislative_definitions. Works without the admin UI.

## Arguments

The user provides law names in any of these formats:

| Input | Interpretation |
|-------|---------------|
| `UK_ukpga_1994_39` | Single law by name |
| `ukpga/1994/39` | Single law by path components |
| `UK_ukpga_1994_39 UK_uksi_2013_240` | Multiple laws (space-separated) |
| A file path | Read law names from file (one per line) |

## Steps

### 1. Parse the arguments

Convert each input to a record map for `StagedParser`:

```
UK_ukpga_1994_39 → %{type_code: "ukpga", Year: 1994, Number: "39"}
uksi/2013/240    → %{type_code: "uksi", Year: 2013, Number: "240"}
```

Split on `_` (for `UK_type_year_number` format) or `/` (for path format). Extract `type_code`, `Year` (integer), and `Number` (string).

If the argument looks like a file path (contains `/` with directory components or ends in `.txt`), read it as a file with one law name per line.

### 2. Parse each law

For each law, run from `backend/` directory:

```bash
mix run -e '
alias SertantaiLegal.Scraper.{StagedParser, LawParser}

record = %{type_code: "<type>", Year: <year>, Number: "<number>"}
{:ok, result} = StagedParser.parse(record)
IO.puts("Title: #{result.record.title_en}")

case LawParser.parse_record(result.record, persist: true) do
  {:ok, _} -> IO.puts("Persisted OK")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
'
```

This runs the full 5-stage pipeline:
1. **Metadata** — title, dates, SI codes, subjects from introduction XML
2. **Extent** — geographic extent (E+W+S+NI) from contents XML
3. **Enacted_by** — enacting parent laws
4. **Amending** — outgoing amendment relationships
5. **Amended_by** — incoming amendment relationships

Then persists/upserts to `legal_register` via `LawParser.parse_record`.

### 3. Parse definitions

After LRT metadata is persisted, parse definitions from body XML:

```bash
mix run -e '
alias SertantaiLegal.Scraper.{DefinitionParser, DefinitionPersister}
alias SertantaiLegal.Scraper.LegislationGovUk.Client

{:ok, xml} = Client.fetch_xml("/<type_code>/<year>/<number>/body/data.xml")
defs = DefinitionParser.parse(xml, %{law_name: "<law_name>", type_code: "<type_code>"})
IO.puts("Parsed #{length(defs)} definitions")

if defs != [] do
  {:ok, result} = DefinitionPersister.persist(defs, "<law_name>")
  IO.puts("Upserted #{result.upserted}")
end
'
```

### 4. For multiple laws

When processing multiple laws, combine into a single `mix run` call to avoid repeated app startup:

```bash
mix run -e '
alias SertantaiLegal.Scraper.{StagedParser, LawParser, DefinitionParser, DefinitionPersister}
alias SertantaiLegal.Scraper.LegislationGovUk.Client

laws = [
  %{type_code: "ukpga", Year: 1994, Number: "39"},
  %{type_code: "uksi", Year: 2013, Number: "240"}
]

Enum.each(laws, fn record ->
  name = "UK_#{record.type_code}_#{record[:Year]}_#{record[:Number]}"
  IO.puts("\n── #{name} ──")

  # LRT metadata
  {:ok, result} = StagedParser.parse(record)
  IO.puts("Title: #{result.record.title_en}")
  LawParser.parse_record(result.record, persist: true)

  # Definitions
  path = "/#{record.type_code}/#{record[:Year]}/#{record[:Number]}/body/data.xml"
  case Client.fetch_xml(path) do
    {:ok, xml} ->
      defs = DefinitionParser.parse(xml, %{law_name: name, type_code: record.type_code})
      if defs != [] do
        {:ok, r} = DefinitionPersister.persist(defs, name)
        IO.puts("  #{r.upserted} definitions")
      else
        IO.puts("  no definitions")
      end
    {:error, code, msg} ->
      IO.puts("  fetch error: #{code} #{msg}")
  end
end)
'
```

### 5. Report results

After all laws are parsed, report:
- How many laws were parsed successfully
- How many definitions were upserted
- Any errors

### 6. Optional: Re-resolve

If the user asks, or if the parsed laws are parent laws referenced by other definitions, offer to re-run the resolver:

```bash
mix run -e '
{:ok, result} = SertantaiLegal.Scraper.RootResolver.resolve_all(force: true)
IO.inspect(result)
'
```

## Notes

- All commands run from `backend/` directory
- Rate limiting: legislation.gov.uk has a ~2s recommended delay between requests. For >10 laws, add `Process.sleep(2000)` between iterations
- The `StagedParser.parse` + `LawParser.parse_record(persist: true)` pattern is the same code path the admin UI uses
- Timeout: set `timeout: 60000` on Bash calls — some large Acts take time to fetch
