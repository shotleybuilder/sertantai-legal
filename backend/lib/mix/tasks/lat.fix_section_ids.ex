defmodule Mix.Tasks.Lat.FixSectionIds do
  @moduledoc """
  Fix corrupted section_ids in legal_articles (Issue #120).

  Re-parses laws with the fixed parser, compares against existing data
  using provision text as the stable join key, builds a corrections
  table, and optionally applies the corrections.

  ## Usage

      # Dry run — single law
      mix lat.fix_section_ids UK_ssi_2009_140

      # Dry run — all affected laws (with doubled section_ids)
      mix lat.fix_section_ids --all

      # Apply corrections
      mix lat.fix_section_ids UK_ssi_2009_140 --apply

      # Batch of 50
      mix lat.fix_section_ids --all --batch 50 --apply

  ## How it works

  1. Fetches body XML from legislation.gov.uk
  2. Parses with the fixed parser → new rows with correct section_ids
  3. Joins existing → new on (law_name, text) to match rows
  4. Where section_id differs → rewrite correction
  5. Existing rows with no text match in new → delete (wrapper P2s)
  6. If --apply: updates legal_articles + downstream in a transaction
  """

  use Mix.Task
  require Logger

  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Repo

  @shortdoc "Fix doubled section_ids (Issue #120)"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [apply: :boolean, all: :boolean, batch: :integer],
        aliases: []
      )

    apply? = Keyword.get(opts, :apply, false)
    batch_size = Keyword.get(opts, :batch, nil)

    law_names =
      if Keyword.get(opts, :all, false) do
        find_affected_laws()
      else
        case positional do
          [name] -> [name]
          _ -> Mix.raise("Usage: mix lat.fix_section_ids LAW_NAME [--apply] or --all [--batch N]")
        end
      end

    law_names =
      if batch_size do
        Enum.take(law_names, batch_size)
      else
        law_names
      end

    IO.puts("Processing #{length(law_names)} law(s)...\n")

    all_corrections =
      Enum.flat_map(law_names, fn law_name ->
        case process_law(law_name) do
          {:ok, corrections} ->
            corrections

          {:error, reason} ->
            IO.puts("  ✗ #{law_name}: #{reason}")
            []
        end
      end)

    # Summary
    rewrites = Enum.filter(all_corrections, &(&1.action == :rewrite))
    deletes = Enum.filter(all_corrections, &(&1.action == :delete))
    no_change = Enum.count(all_corrections, &(&1.action == :no_change))
    unmatched = Enum.filter(all_corrections, &(&1.action == :unmatched_new))
    dupes = Enum.filter(all_corrections, &(&1.action == :duplicate_text))

    IO.puts("\n── Summary ──")

    IO.puts(
      "  #{no_change} unchanged, #{length(rewrites)} rewrites, " <>
        "#{length(deletes)} deletes, #{length(unmatched)} unmatched new, " <>
        "#{length(dupes)} duplicate text"
    )

    if apply? and (rewrites != [] or deletes != []) do
      IO.puts("\nApplying corrections...")
      apply_corrections(rewrites, deletes)
    else
      if rewrites != [] or deletes != [] do
        IO.puts("\nDry run — use --apply to execute corrections")
      end
    end
  end

  # ── Process a single law ──────────────────────────────────────────

  defp process_law(law_name) do
    IO.puts("── #{law_name} ──")

    with {:ok, type_code} <- lookup_type_code(law_name),
         {:ok, xml} <- fetch_xml(law_name) do
      # Re-parse with fixed parser
      new_rows = LatParser.parse(xml, %{law_name: law_name, type_code: type_code})

      # Load existing rows
      existing_rows = load_existing_rows(law_name)

      # Sense checks
      IO.puts(
        "  rows: #{length(existing_rows)} existing → #{length(new_rows)} new " <>
          "(#{length(existing_rows) - length(new_rows)} removed)"
      )

      # Build corrections by text match
      corrections = build_corrections(existing_rows, new_rows)

      rewrites = Enum.count(corrections, &(&1.action == :rewrite))
      deletes = Enum.count(corrections, &(&1.action == :delete))
      no_change = Enum.count(corrections, &(&1.action == :no_change))
      dupes = Enum.count(corrections, &(&1.action == :duplicate_text))

      IO.puts("  #{no_change} ok, #{rewrites} rewrite, #{deletes} delete, #{dupes} dupe text")

      # Show rewrites
      corrections
      |> Enum.filter(&(&1.action == :rewrite))
      |> Enum.take(5)
      |> Enum.each(fn c ->
        IO.puts("    #{c.old_section_id} → #{c.new_section_id}")
      end)

      if rewrites > 5 do
        IO.puts("    ... and #{rewrites - 5} more")
      end

      {:ok, corrections}
    end
  end

  # ── Build corrections via text match ──────────────────────────────

  defp build_corrections(existing_rows, new_rows) do
    # Index new rows by (law_name, text) — text is the stable key
    # Handle duplicate texts: first match wins, flag the rest
    {new_by_text, new_dupes} = index_by_text(new_rows, :section_id)

    # Match existing rows against new
    {matched_texts, corrections} =
      Enum.reduce(existing_rows, {MapSet.new(), []}, fn old, {seen, acc} ->
        key = {old.law_name, old.text}

        cond do
          # Null/empty text — can't match, flag for deletion
          is_nil(old.text) or old.text == "" ->
            correction = %{
              old_section_id: old.section_id,
              new_section_id: nil,
              action: :delete,
              law_name: old.law_name
            }

            {seen, [correction | acc]}

          # Already matched this text — duplicate in existing (wrapper P2 has same text as parent)
          MapSet.member?(seen, key) ->
            correction = %{
              old_section_id: old.section_id,
              new_section_id: nil,
              action: :delete,
              law_name: old.law_name
            }

            {seen, [correction | acc]}

          # Text match found in new
          Map.has_key?(new_by_text, key) ->
            new_section_id = Map.get(new_by_text, key)

            action =
              if old.section_id == new_section_id, do: :no_change, else: :rewrite

            correction = %{
              old_section_id: old.section_id,
              new_section_id: new_section_id,
              action: action,
              law_name: old.law_name
            }

            {MapSet.put(seen, key), [correction | acc]}

          # No match in new — old row doesn't exist after re-parse
          true ->
            correction = %{
              old_section_id: old.section_id,
              new_section_id: nil,
              action: :delete,
              law_name: old.law_name
            }

            {seen, [correction | acc]}
        end
      end)

    # Check for new rows that have no match in existing (shouldn't happen for fixes)
    unmatched_new =
      new_rows
      |> Enum.reject(fn r ->
        key = {r.law_name, r[:text]}
        MapSet.member?(matched_texts, key) or is_nil(r[:text]) or r[:text] == ""
      end)
      |> Enum.map(fn r ->
        %{
          old_section_id: nil,
          new_section_id: r.section_id,
          action: :unmatched_new,
          law_name: r.law_name
        }
      end)

    # Flag duplicate text entries
    dupe_corrections =
      Enum.map(new_dupes, fn {key, section_ids} ->
        {law_name, _text} = key

        %{
          old_section_id: nil,
          new_section_id: Enum.join(section_ids, ", "),
          action: :duplicate_text,
          law_name: law_name
        }
      end)

    Enum.reverse(corrections) ++ unmatched_new ++ dupe_corrections
  end

  # Build a map of {law_name, text} → section_id, tracking duplicates
  defp index_by_text(rows, id_field) do
    Enum.reduce(rows, {%{}, []}, fn row, {index, dupes} ->
      text = Map.get(row, :text) || row[:text]
      law_name = Map.get(row, :law_name) || row[:law_name]
      section_id = Map.get(row, id_field)

      if is_nil(text) or text == "" do
        {index, dupes}
      else
        key = {law_name, text}

        if Map.has_key?(index, key) do
          existing_id = Map.get(index, key)
          {index, [{key, [existing_id, section_id]} | dupes]}
        else
          {Map.put(index, key, section_id), dupes}
        end
      end
    end)
  end

  # ── Apply corrections ────────────────────────────────────────────

  defp apply_corrections(rewrites, deletes) do
    Repo.transaction(fn ->
      # Update downstream tables first
      Enum.each(rewrites, fn c ->
        Repo.query!(
          "UPDATE control_mappings SET section_id = $1 WHERE section_id = $2",
          [c.new_section_id, c.old_section_id]
        )

        Repo.query!(
          "UPDATE amendment_annotations SET affected_sections = array_replace(affected_sections, $1, $2) WHERE $1 = ANY(affected_sections)",
          [c.old_section_id, c.new_section_id]
        )
      end)

      # Delete downstream references for removed rows
      Enum.each(deletes, fn c ->
        Repo.query!(
          "DELETE FROM control_mappings WHERE section_id = $1",
          [c.old_section_id]
        )

        Repo.query!(
          "UPDATE amendment_annotations SET affected_sections = array_remove(affected_sections, $1) WHERE $1 = ANY(affected_sections)",
          [c.old_section_id]
        )
      end)

      # Rewrite section_ids in legal_articles
      Enum.each(rewrites, fn c ->
        Repo.query!(
          "UPDATE legal_articles SET section_id = $1 WHERE section_id = $2",
          [c.new_section_id, c.old_section_id]
        )
      end)

      # Delete wrapper P2 rows from legal_articles
      Enum.each(deletes, fn c ->
        Repo.query!(
          "DELETE FROM legal_articles WHERE section_id = $1",
          [c.old_section_id]
        )
      end)

      IO.puts("  Applied #{length(rewrites)} rewrites, #{length(deletes)} deletes")
    end)
  end

  # ── Data loading ──────────────────────────────────────────────────

  defp lookup_type_code(law_name) do
    case Repo.query("SELECT type_code FROM legal_register WHERE name = $1 LIMIT 1", [law_name]) do
      {:ok, %{rows: [[type_code]]}} -> {:ok, type_code}
      _ -> {:error, "law not found in legal_register"}
    end
  end

  defp load_existing_rows(law_name) do
    query = """
    SELECT section_id, law_name, text
    FROM legal_articles
    WHERE law_name = $1
    ORDER BY position
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [section_id, law_name, text] ->
          %{section_id: section_id, law_name: law_name, text: text}
        end)

      _ ->
        []
    end
  end

  defp fetch_xml(law_name) do
    slash_path = IdField.normalize_to_slash_format(law_name)
    path = "/#{slash_path}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} -> {:ok, xml}
      {:ok, :html, _html} -> {:error, "received HTML instead of XML"}
      {:error, _code, reason} -> {:error, reason}
    end
  end

  # ── Find affected laws ────────────────────────────────────────────

  defp find_affected_laws do
    query = """
    WITH doubled AS (
      SELECT DISTINCT law_name FROM legal_articles
      WHERE section_id ~ '\\.(\\d+[A-Za-z]*)\\(\\1\\)'
    )
    SELECT law_name FROM doubled
    WHERE NOT EXISTS (
      SELECT 1 FROM legal_articles la2
      WHERE la2.law_name = doubled.law_name
        AND la2.section_type = 'paragraph'
        AND 1 = 0
    )
    ORDER BY law_name
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [name] -> name end)
      _ -> []
    end
  end
end
