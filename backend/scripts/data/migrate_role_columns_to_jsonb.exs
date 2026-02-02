# Data Migration Script: Migrate role text columns to JSONB
#
# This script transforms the legacy text columns:
#   - article_role, role_article → role_details
#   - role_gvt_article, article_role_gvt → role_gvt_details
#
# Run: cd backend && mix run scripts/data/migrate_role_columns_to_jsonb.exs
#
# The JSONB structure:
# {
#   "entries": [{"role": "Ind: Person", "article": "section/1"}, ...],
#   "roles": ["Ind: Person", "Org: Employer"],
#   "articles": ["section/1", "regulation/4"]
# }

alias SertantaiLegal.Repo
import Ecto.Query

defmodule RoleMigration do
  @moduledoc """
  Migrates role text columns to consolidated JSONB format.

  Source column formats:
  - article_role: "URL\nrole1; role2\n\nURL2\nrole3; role4"
  - role_article: "[Role1]\nURL1\nURL2\n\n[Role2]\nURL3"
  """

  @doc """
  Parse article_role format: URL followed by semicolon-separated roles on next line.
  """
  def parse_article_role(nil), do: []
  def parse_article_role(""), do: []

  def parse_article_role(text) do
    # Split into blocks separated by double newlines
    text
    |> String.split(~r/\n\n+/)
    |> Enum.flat_map(&parse_article_role_block/1)
  end

  defp parse_article_role_block(block) do
    lines =
      block
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [url, roles_str | _] ->
        if String.starts_with?(url, "http") do
          article = extract_article_path(url)

          roles_str
          |> String.split(";")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn role -> %{"role" => role, "article" => article} end)
        else
          []
        end

      _ ->
        []
    end
  end

  @doc """
  Parse role_article format: [Role] followed by URLs on subsequent lines.
  """
  def parse_role_article(nil), do: []
  def parse_role_article(""), do: []

  def parse_role_article(text) do
    # Split into blocks separated by double newlines
    text
    |> String.split(~r/\n\n+/)
    |> Enum.flat_map(&parse_role_article_block/1)
  end

  defp parse_role_article_block(block) do
    lines =
      block
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [role_line | url_lines] when is_binary(role_line) ->
        # Role is in brackets: [Role Name]
        role =
          role_line
          |> String.replace(~r/^\[/, "")
          |> String.replace(~r/\]$/, "")
          |> String.trim()

        if role != "" do
          url_lines
          |> Enum.filter(&String.starts_with?(&1, "http"))
          |> Enum.map(fn url ->
            %{"role" => role, "article" => extract_article_path(url)}
          end)
        else
          []
        end

      _ ->
        []
    end
  end

  @doc """
  Extract article path from full URL.
  e.g., "https://legislation.gov.uk/ukpga/1963/41/section/1" → "section/1"
  """
  def extract_article_path(url) do
    # Pattern: .../uk<type>/<year>/<num>/path or .../uk<type>/<num>/<num>/path
    # e.g., https://legislation.gov.uk/ukpga/1963/41/section/1 → section/1
    # e.g., https://legislation.gov.uk/uksi/2005/2035/regulation/13 → regulation/13
    cond do
      # Match pattern: /uk<type>/<4-digit-year>/<num>/<path>
      match = Regex.run(~r|/uk[a-z]+/[0-9]+/[0-9]+/(.+)$|, url) ->
        Enum.at(match, 1)

      # Fallback to full URL if pattern doesn't match
      true ->
        url
    end
  end

  @doc """
  Merge entries from both source columns, deduplicating.
  """
  def merge_entries(entries1, entries2) do
    (entries1 ++ entries2)
    |> Enum.uniq_by(fn entry -> {entry["role"], entry["article"]} end)
    |> Enum.sort_by(fn entry -> {entry["article"] || "", entry["role"] || ""} end)
  end

  @doc """
  Build the consolidated JSONB structure from entries.
  """
  def build_jsonb([]), do: nil

  def build_jsonb(entries) do
    roles =
      entries
      |> Enum.map(& &1["role"])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    articles =
      entries
      |> Enum.map(& &1["article"])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    %{
      "entries" => entries,
      "roles" => roles,
      "articles" => articles
    }
  end

  @doc """
  Process a single record, returning the update params.
  """
  def process_record(record) do
    # Parse role_details from article_role and role_article
    entries_from_article_role = parse_article_role(record.article_role)
    entries_from_role_article = parse_role_article(record.role_article)
    role_entries = merge_entries(entries_from_article_role, entries_from_role_article)
    role_details = build_jsonb(role_entries)

    # Parse role_gvt_details from article_role_gvt and role_gvt_article
    entries_from_article_role_gvt = parse_article_role(record.article_role_gvt)
    entries_from_role_gvt_article = parse_role_article(record.role_gvt_article)
    role_gvt_entries = merge_entries(entries_from_article_role_gvt, entries_from_role_gvt_article)
    role_gvt_details = build_jsonb(role_gvt_entries)

    {role_details, role_gvt_details}
  end

  @doc """
  Run the migration in batches.
  """
  def run(batch_size \\ 500) do
    IO.puts("Starting role columns migration to JSONB...")

    # Get records that have any of the source columns populated
    query =
      from(u in "uk_lrt",
        where:
          not is_nil(u.article_role) or
            not is_nil(u.role_article) or
            not is_nil(u.role_gvt_article) or
            not is_nil(u.article_role_gvt),
        select: %{
          id: u.id,
          article_role: u.article_role,
          role_article: u.role_article,
          role_gvt_article: u.role_gvt_article,
          article_role_gvt: u.article_role_gvt
        }
      )

    records = Repo.all(query)
    total = length(records)
    IO.puts("Found #{total} records to migrate")

    records
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      batch_start = (batch_num - 1) * batch_size + 1
      batch_end = min(batch_num * batch_size, total)
      IO.puts("Processing batch #{batch_num}: records #{batch_start}-#{batch_end}")

      Repo.transaction(fn ->
        Enum.each(batch, fn record ->
          {role_details, role_gvt_details} = process_record(record)

          from(u in "uk_lrt", where: u.id == ^record.id)
          |> Repo.update_all(
            set: [
              role_details: role_details,
              role_gvt_details: role_gvt_details
            ]
          )
        end)
      end)
    end)

    IO.puts("Migration complete!")

    # Print summary
    verify_migration()
  end

  @doc """
  Verify the migration results.
  """
  def verify_migration do
    IO.puts("\n=== Migration Verification ===")

    # Count records with role_details
    role_count =
      Repo.one(
        from(u in "uk_lrt",
          where: not is_nil(u.role_details),
          select: count()
        )
      )

    IO.puts("Records with role_details: #{role_count}")

    # Count records with role_gvt_details
    role_gvt_count =
      Repo.one(
        from(u in "uk_lrt",
          where: not is_nil(u.role_gvt_details),
          select: count()
        )
      )

    IO.puts("Records with role_gvt_details: #{role_gvt_count}")

    # Count total entries
    entry_stats =
      Repo.one(
        from(u in "uk_lrt",
          where: not is_nil(u.role_details),
          select: %{
            total_entries: fragment("SUM(jsonb_array_length(role_details->'entries'))"),
            total_roles: fragment("SUM(jsonb_array_length(role_details->'roles'))"),
            total_articles: fragment("SUM(jsonb_array_length(role_details->'articles'))")
          }
        )
      )

    IO.puts("Total role entries: #{entry_stats.total_entries}")
    IO.puts("Total unique roles: #{entry_stats.total_roles}")
    IO.puts("Total unique articles: #{entry_stats.total_articles}")

    # Sample a record
    sample =
      Repo.one(
        from(u in "uk_lrt",
          where: not is_nil(u.role_details),
          select: %{
            id: u.id,
            name: u.name,
            role_details: u.role_details,
            role_gvt_details: u.role_gvt_details
          },
          limit: 1
        )
      )

    if sample do
      IO.puts("\nSample record (#{sample.name}):")
      IO.puts("role_details entries count: #{length(sample.role_details["entries"] || [])}")

      IO.puts(
        "First 3 entries: #{inspect(Enum.take(sample.role_details["entries"] || [], 3), pretty: true)}"
      )

      if sample.role_gvt_details do
        IO.puts(
          "\nrole_gvt_details entries count: #{length(sample.role_gvt_details["entries"] || [])}"
        )

        IO.puts(
          "First 3 entries: #{inspect(Enum.take(sample.role_gvt_details["entries"] || [], 3), pretty: true)}"
        )
      end
    end
  end
end

# Run the migration
RoleMigration.run()
