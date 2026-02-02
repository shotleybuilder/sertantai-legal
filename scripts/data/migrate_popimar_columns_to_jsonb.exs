# Migrate POPIMAR article text columns to consolidated JSONB column
#
# Transforms 4 text columns into 1 JSONB column:
# - popimar_article, popimar_article_clause, article_popimar, article_popimar_clause
# → popimar_details
#
# The JSONB column has structure:
# {
#   "entries": [
#     {"category": "Records", "article": "regulation/4"}
#   ],
#   "categories": ["Records", ...],
#   "articles": ["regulation/4", ...]
# }
#
# Usage:
#   cd backend
#   mix run ../scripts/data/migrate_popimar_columns_to_jsonb.exs
#   mix run ../scripts/data/migrate_popimar_columns_to_jsonb.exs --dry-run

defmodule PopimarColumnMigrator do
  alias SertantaiLegal.Repo

  def run(dry_run \\ false) do
    IO.puts("\n=== Migrating POPIMAR columns to JSONB ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}\n")

    migrate_popimar_details(dry_run)
    show_summary()
  end

  defp migrate_popimar_details(dry_run) do
    IO.puts("\n--- Migrating popimar_article → popimar_details ---")

    # Get records with data in popimar_article (primary source)
    query = """
    SELECT id, name, popimar_article, popimar_article_clause
    FROM uk_lrt
    WHERE popimar_article IS NOT NULL
      AND popimar_article != ''
    """

    {:ok, result} = Repo.query(query)
    records = result.rows

    IO.puts("Found #{length(records)} records with popimar_article data")

    if dry_run do
      # Show samples
      records
      |> Enum.take(3)
      |> Enum.each(fn [_id, name, popimar_article, popimar_article_clause] ->
        jsonb = parse_popimar_text(popimar_article, popimar_article_clause)
        IO.puts("\n#{name}:")
        IO.puts("  Entries: #{length(jsonb["entries"])}")
        IO.puts("  Categories: #{inspect(Enum.take(jsonb["categories"], 5))}")
        IO.puts("  Articles: #{inspect(Enum.take(jsonb["articles"], 5))}")

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
          count = migrate_batch(batch)
          IO.write(".")
          acc + count
        end)

      IO.puts("\nMigrated #{migrated} records to popimar_details")
    end
  end

  defp migrate_batch(records) do
    Enum.reduce(records, 0, fn [id, _name, popimar_article, popimar_article_clause], count ->
      jsonb = parse_popimar_text(popimar_article, popimar_article_clause)

      update_query = """
      UPDATE uk_lrt
      SET popimar_details = $1
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
  Parse the POPIMAR text format into JSONB structure.

  Input format (popimar_article):
  ```
  [Category Name]
  https://legislation.gov.uk/type/year/number/article
  https://legislation.gov.uk/type/year/number/article2

  [Another Category]
  https://legislation.gov.uk/type/year/number/article3
  ```

  Input format (popimar_article_clause) - optional, has combined categories:
  ```
  [Category1; Category2]
  https://legislation.gov.uk/type/year/number/article
  ```

  Output format:
  ```
  {
    "entries": [{"category": "...", "article": "..."}],
    "categories": ["..."],
    "articles": ["..."]
  }
  ```
  """
  def parse_popimar_text(nil, _clause), do: empty_jsonb()
  def parse_popimar_text("", _clause), do: empty_jsonb()

  def parse_popimar_text(popimar_article, popimar_article_clause) do
    # Parse primary source (popimar_article)
    entries_from_article = parse_popimar_blocks(popimar_article)

    # Parse clause source if available (may have combined categories)
    entries_from_clause =
      if popimar_article_clause && popimar_article_clause != "" do
        parse_popimar_blocks(popimar_article_clause)
      else
        []
      end

    # Combine entries, preferring clause version if it has more detail
    all_entries = merge_entries(entries_from_article, entries_from_clause)

    categories = all_entries |> Enum.map(& &1["category"]) |> Enum.uniq() |> Enum.sort()
    articles = all_entries |> Enum.map(& &1["article"]) |> Enum.uniq() |> Enum.sort()

    %{
      "entries" => all_entries,
      "categories" => categories,
      "articles" => articles
    }
  end

  defp empty_jsonb do
    %{"entries" => [], "categories" => [], "articles" => []}
  end

  # Parse POPIMAR text into blocks by [Category] headers
  defp parse_popimar_blocks(text) do
    # Match [Category Name] at start of line
    regex = ~r/^\[([^\]]+)\]\s*$/m

    parts = Regex.split(regex, text, include_captures: true, trim: true)

    # Pair headers with their content
    parts
    |> Enum.chunk_every(2)
    |> Enum.filter(fn chunk -> length(chunk) == 2 end)
    |> Enum.flat_map(fn [header, content] ->
      # Extract category name from [Name] format
      # Handle combined categories like [Cat1; Cat2; Cat3]
      category_str = header |> String.trim() |> String.replace(~r/^\[|\]$/, "")
      categories = String.split(category_str, ~r/\s*;\s*/) |> Enum.map(&String.trim/1)

      # Extract article URLs from content
      articles =
        content
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "https://legislation.gov.uk/"))
        |> Enum.map(&extract_article_path/1)

      # Create entry for each category-article combination
      for category <- categories, article <- articles do
        %{"category" => category, "article" => article}
      end
    end)
  end

  # Merge entries from article and clause sources
  # Deduplicate by category+article combination
  defp merge_entries(entries_article, entries_clause) do
    all = entries_article ++ entries_clause

    all
    |> Enum.uniq_by(fn e -> {e["category"], e["article"]} end)
  end

  # Extract article path from full URL
  # Input: https://legislation.gov.uk/uksi/2005/621/regulation/4
  # Output: regulation/4
  defp extract_article_path(url) do
    case Regex.run(~r{legislation\.gov\.uk/[^/]+/\d+/\d+/(.+)$}, url) do
      [_, path] ->
        path

      _ ->
        # Fallback - strip base URL
        url |> String.replace(~r{^https?://[^/]+/[^/]+/\d+/\d+/?}, "")
    end
  end

  defp show_summary do
    query = """
    SELECT
      COUNT(*) FILTER (WHERE popimar_details IS NOT NULL) as with_details,
      COUNT(*) FILTER (WHERE popimar_article IS NOT NULL) as with_article,
      COUNT(*) as total
    FROM uk_lrt
    """

    {:ok, result} = Repo.query(query)
    [[with_details, with_article, total]] = result.rows

    IO.puts("\n=== Migration Summary ===")
    IO.puts("Total records: #{total}")
    IO.puts("Records with popimar_article: #{with_article}")
    IO.puts("Records with popimar_details: #{with_details}")

    # Storage comparison
    storage_query = """
    SELECT
      pg_size_pretty(sum(pg_column_size(popimar_article))) as article_size,
      pg_size_pretty(sum(pg_column_size(popimar_article_clause))) as clause_size,
      pg_size_pretty(sum(pg_column_size(article_popimar))) as inverse_size,
      pg_size_pretty(sum(pg_column_size(article_popimar_clause))) as inverse_clause_size,
      pg_size_pretty(sum(pg_column_size(popimar_details))) as details_size
    FROM uk_lrt
    """

    {:ok, storage_result} = Repo.query(storage_query)
    [[article, clause, inverse, inverse_clause, details]] = storage_result.rows

    IO.puts("\n=== Storage Comparison ===")
    IO.puts("Old columns:")
    IO.puts("  popimar_article: #{article || "0 bytes"}")
    IO.puts("  popimar_article_clause: #{clause || "0 bytes"}")
    IO.puts("  article_popimar: #{inverse || "0 bytes"}")
    IO.puts("  article_popimar_clause: #{inverse_clause || "0 bytes"}")
    IO.puts("New column:")
    IO.puts("  popimar_details: #{details || "0 bytes"}")
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

PopimarColumnMigrator.run(dry_run)
