# Migrate holder/article text columns to consolidated JSONB columns
#
# Transforms 16 text columns (4 per holder type) into 4 JSONB columns:
# - duties, rights, responsibilities, powers
#
# Each JSONB column has structure:
# {
#   "entries": [
#     {"holder": "Ind: Person", "article": "regulation/4", "duty_type": "DUTY", "clause": "..."}
#   ],
#   "holders": ["Ind: Person", ...],
#   "articles": ["regulation/4", ...]
# }
#
# Usage:
#   cd backend
#   mix run ../scripts/data/migrate_holder_columns_to_jsonb.exs
#   mix run ../scripts/data/migrate_holder_columns_to_jsonb.exs --dry-run

defmodule HolderColumnMigrator do
  alias SertantaiLegal.Repo

  @holder_types [
    {:duties, "duty_holder_article_clause", "DUTY"},
    {:rights, "rights_holder_article_clause", "RIGHT"},
    {:responsibilities, "responsibility_holder_article_clause", "RESPONSIBILITY"},
    {:powers, "power_holder_article_clause", "POWER"}
  ]

  def run(dry_run \\ false) do
    IO.puts("\n=== Migrating holder columns to JSONB ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}\n")

    for {jsonb_col, source_col, default_type} <- @holder_types do
      migrate_holder_type(jsonb_col, source_col, default_type, dry_run)
    end

    show_summary()
  end

  defp migrate_holder_type(jsonb_col, source_col, default_type, dry_run) do
    IO.puts("\n--- Migrating #{source_col} → #{jsonb_col} ---")

    # Get records with data in source column
    query = """
    SELECT id, name, #{source_col}
    FROM uk_lrt
    WHERE #{source_col} IS NOT NULL
      AND #{source_col} != ''
      AND #{source_col} != '{}'
    """

    {:ok, result} = Repo.query(query)
    records = result.rows

    IO.puts("Found #{length(records)} records with #{source_col} data")

    if dry_run do
      # Show sample
      records
      |> Enum.take(2)
      |> Enum.each(fn [_id, name, text] ->
        jsonb = parse_holder_text(text, default_type)
        IO.puts("\n#{name}:")
        IO.puts("  Entries: #{length(jsonb["entries"])}")
        IO.puts("  Holders: #{inspect(jsonb["holders"])}")
        IO.puts("  Articles: #{Enum.take(jsonb["articles"], 3) |> inspect()}")

        if length(jsonb["entries"]) > 0 do
          IO.puts("  Sample entry: #{inspect(Enum.at(jsonb["entries"], 0))}")
        end
      end)
    else
      # Migrate all records
      migrated =
        records
        |> Enum.chunk_every(100)
        |> Enum.reduce(0, fn batch, acc ->
          count = migrate_batch(batch, jsonb_col, default_type)
          IO.write(".")
          acc + count
        end)

      IO.puts("\nMigrated #{migrated} records to #{jsonb_col}")
    end
  end

  defp migrate_batch(records, jsonb_col, default_type) do
    Enum.reduce(records, 0, fn [id, _name, text], count ->
      jsonb = parse_holder_text(text, default_type)

      # Use parameterized query with direct map - Postgrex handles JSONB encoding
      update_query = """
      UPDATE uk_lrt
      SET #{jsonb_col} = $1
      WHERE id = $2
      """

      case Repo.query(update_query, [jsonb, id]) do
        {:ok, _} ->
          count + 1

        {:error, e} ->
          IO.puts("\nError updating #{id}: #{inspect(e)}")
          count
      end
    end)
  end

  @doc """
  Parse the text format into JSONB structure.

  Input format:
  ```
  [Holder Category: Name]
  https://legislation.gov.uk/type/year/number/article
  DUTY
  👤Holder Category: Name
  📌clause text here
  DUTY
  👤Holder Category: Name
  📌another clause

  [Another Holder]
  https://legislation.gov.uk/type/year/number/article2
  ...
  ```

  Output format:
  ```
  {
    "entries": [{"holder": "...", "article": "...", "duty_type": "...", "clause": "..."}],
    "holders": ["..."],
    "articles": ["..."]
  }
  ```
  """
  def parse_holder_text(nil, _default_type), do: empty_jsonb()
  def parse_holder_text("", _default_type), do: empty_jsonb()
  def parse_holder_text("{}", _default_type), do: empty_jsonb()

  def parse_holder_text(text, default_type) do
    # Split into holder blocks (separated by [Holder Name] headers)
    blocks = split_into_holder_blocks(text)

    entries =
      blocks
      |> Enum.flat_map(fn {holder, block_text} ->
        parse_holder_block(holder, block_text, default_type)
      end)

    holders = entries |> Enum.map(& &1["holder"]) |> Enum.uniq() |> Enum.sort()
    articles = entries |> Enum.map(& &1["article"]) |> Enum.uniq() |> Enum.sort()

    %{
      "entries" => entries,
      "holders" => holders,
      "articles" => articles
    }
  end

  defp empty_jsonb do
    %{"entries" => [], "holders" => [], "articles" => []}
  end

  # Split text into blocks by [Holder Name] headers
  defp split_into_holder_blocks(text) do
    # Match [Category: Name] or [Name] at start of line
    regex = ~r/^\[([^\]]+)\]\s*$/m

    parts = Regex.split(regex, text, include_captures: true, trim: true)

    # Pair headers with their content
    parts
    |> Enum.chunk_every(2)
    |> Enum.filter(fn chunk -> length(chunk) == 2 end)
    |> Enum.map(fn [header, content] ->
      # Extract holder name from [Name] format
      holder = header |> String.trim() |> String.replace(~r/^\[|\]$/, "")
      {holder, content}
    end)
  end

  # Parse a single holder's block into entries
  defp parse_holder_block(holder, block_text, default_type) do
    lines = String.split(block_text, "\n") |> Enum.map(&String.trim/1)

    # State machine to parse entries
    parse_lines(lines, holder, default_type, nil, nil, nil, [])
  end

  # Recursive line parser
  # State: current_article, current_duty_type, current_clause, accumulated entries
  defp parse_lines([], _holder, _default_type, _article, _duty_type, _clause, entries) do
    Enum.reverse(entries)
  end

  defp parse_lines([line | rest], holder, default_type, article, duty_type, clause, entries) do
    cond do
      # URL line - extract article path
      String.starts_with?(line, "https://legislation.gov.uk/") ->
        new_article = extract_article_path(line)
        parse_lines(rest, holder, default_type, new_article, duty_type, clause, entries)

      # Duty type line (DUTY, RIGHT, POWER, RESPONSIBILITY)
      line in ["DUTY", "RIGHT", "POWER", "RESPONSIBILITY"] ->
        parse_lines(rest, holder, default_type, article, line, clause, entries)

      # Holder line with emoji - confirms holder (skip, we already have it)
      String.starts_with?(line, "👤") ->
        parse_lines(rest, holder, default_type, article, duty_type, clause, entries)

      # Clause line with emoji - create entry
      String.starts_with?(line, "📌") ->
        clause_text = String.replace_prefix(line, "📌", "") |> String.trim()

        entry = %{
          "holder" => holder,
          "article" => article,
          "duty_type" => duty_type || default_type,
          "clause" => if(clause_text == "", do: nil, else: clause_text)
        }

        # Only add entry if we have an article
        new_entries = if article, do: [entry | entries], else: entries
        parse_lines(rest, holder, default_type, article, nil, nil, new_entries)

      # Empty line or other - skip
      true ->
        parse_lines(rest, holder, default_type, article, duty_type, clause, entries)
    end
  end

  # Extract article path from full URL
  # Input: https://legislation.gov.uk/uksi/2005/621/regulation/4
  # Output: regulation/4
  defp extract_article_path(url) do
    case Regex.run(~r{legislation\.gov\.uk/[^/]+/\d+/\d+/(.+)$}, url) do
      [_, path] ->
        path

      _ ->
        # Try crossheading format
        case Regex.run(~r{legislation\.gov\.uk/[^/]+/\d+/\d+$}, url) do
          _ -> url |> String.replace(~r{^https?://[^/]+/[^/]+/\d+/\d+/?}, "")
        end
    end
  end

  defp show_summary do
    query = """
    SELECT
      COUNT(*) FILTER (WHERE duties IS NOT NULL) as duties_count,
      COUNT(*) FILTER (WHERE rights IS NOT NULL) as rights_count,
      COUNT(*) FILTER (WHERE responsibilities IS NOT NULL) as responsibilities_count,
      COUNT(*) FILTER (WHERE powers IS NOT NULL) as powers_count,
      COUNT(*) as total
    FROM uk_lrt
    """

    {:ok, result} = Repo.query(query)
    [[duties, rights, responsibilities, powers, total]] = result.rows

    IO.puts("\n=== Migration Summary ===")
    IO.puts("Total records: #{total}")
    IO.puts("Records with duties: #{duties}")
    IO.puts("Records with rights: #{rights}")
    IO.puts("Records with responsibilities: #{responsibilities}")
    IO.puts("Records with powers: #{powers}")
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

HolderColumnMigrator.run(dry_run)
