defmodule Mix.Tasks.Lat.FixSectionIds do
  @moduledoc """
  Fix corrupted section_ids in legal_articles (Issue #120).

  Re-parses laws with the fixed parser, diffs against existing data using
  xml_id as the stable join key, builds a corrections table, and optionally
  applies the corrections.

  ## Usage

      # Dry run — single law (builds corrections, does not apply)
      mix lat.fix_section_ids UK_ssi_2009_140

      # Dry run — all affected laws
      mix lat.fix_section_ids --all

      # Apply corrections
      mix lat.fix_section_ids UK_ssi_2009_140 --apply

  ## How it works

  1. Fetches the XML from legislation.gov.uk
  2. Parses with the fixed parser → new rows with (xml_id, new_section_id)
  3. Walks the XML to extract all xml_ids in document order (including wrapper P2s)
  4. Matches xml_ids to existing legal_articles rows by (law_name, position)
  5. Builds corrections: old_section_id → new_section_id → action
  6. Reports sense checks and corrections summary
  7. If --apply: updates legal_articles + downstream tables in a transaction
  """

  use Mix.Task
  require Logger
  import SweetXml

  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.IdField

  @shortdoc "Fix doubled section_ids (Issue #120)"

  # Elements the parser emits rows for (must match walk_element in lat_parser.ex)
  @structural_elements ~w(Part EUTitle Chapter EUChapter Pblock P1 P2 P3 P4 Schedule SignedSection Tabular Figure)

  # Elements the parser skips
  @skip_elements ~w(BlockAmendment OrderedList UnorderedList Addition Repeal Substitution)

  # Container elements the parser recurses through
  @container_elements ~w(Body Primary Secondary P1para P2para P3para P1group Schedules
    EUPart EUSection EUSubsection EUPreamble Recitals)

  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args, switches: [apply: :boolean, all: :boolean], aliases: [])

    apply? = Keyword.get(opts, :apply, false)

    law_names =
      if Keyword.get(opts, :all, false) do
        find_affected_laws()
      else
        case positional do
          [name] -> [name]
          _ -> Mix.raise("Usage: mix lat.fix_section_ids LAW_NAME [--apply] or --all")
        end
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
    rewrites = Enum.count(all_corrections, &(&1.action == :rewrite))
    deletes = Enum.count(all_corrections, &(&1.action == :delete))
    no_change = Enum.count(all_corrections, &(&1.action == :no_change))

    IO.puts("\n── Summary ──")
    IO.puts("  #{no_change} unchanged, #{rewrites} rewrites, #{deletes} deletes")

    if apply? and (rewrites > 0 or deletes > 0) do
      IO.puts("\nApplying corrections...")
      apply_corrections(all_corrections)
    else
      if rewrites > 0 or deletes > 0 do
        IO.puts("\nDry run — use --apply to execute corrections")
      end
    end
  end

  # ── Process a single law ──────────────────────────────────────────

  defp process_law(law_name) do
    IO.puts("── #{law_name} ──")

    # Look up the law record for type_code
    case lookup_law(law_name) do
      {:ok, law} ->
        type_code = law.type_code

        # Step 1: Fetch XML
        case fetch_xml(law_name, type_code) do
          {:ok, xml} ->
            # Step 2: Re-parse with fixed parser → new rows with xml_id
            new_rows = LatParser.parse(xml, %{law_name: law_name, type_code: type_code})

            # Step 3: Walk XML to extract all xml_ids in document order (including wrapper P2s)
            old_xml_ids = extract_xml_ids_in_document_order(xml)

            # Step 4: Load existing rows, match by position
            existing_rows = load_existing_rows(law_name)

            # Sense checks
            sense_check(law_name, existing_rows, new_rows, old_xml_ids)

            # Step 5: Build corrections
            corrections = build_corrections(law_name, existing_rows, new_rows, old_xml_ids)

            rewrites = Enum.count(corrections, &(&1.action == :rewrite))
            deletes = Enum.count(corrections, &(&1.action == :delete))
            no_change = Enum.count(corrections, &(&1.action == :no_change))
            unmatched = Enum.count(corrections, &(&1.action == :unmatched))

            IO.puts(
              "  #{no_change} ok, #{rewrites} rewrite, #{deletes} delete, #{unmatched} unmatched"
            )

            # Show rewrites
            corrections
            |> Enum.filter(&(&1.action == :rewrite))
            |> Enum.take(10)
            |> Enum.each(fn c ->
              IO.puts("    #{c.old_section_id} → #{c.new_section_id}")
            end)

            if rewrites > 10 do
              IO.puts("    ... and #{rewrites - 10} more")
            end

            {:ok, corrections}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── XML ID Extraction ─────────────────────────────────────────────

  @doc """
  Walk the XML in document order, extracting (xml_id, element_name) for
  every element that the OLD parser would have emitted a row for.
  This includes wrapper P2 rows that the new parser skips.
  Returns a list in document order — position is the 1-based index.
  """
  def extract_xml_ids_in_document_order(xml) do
    doc = SweetXml.parse(xml)

    doc
    |> walk_for_ids()
    |> List.flatten()
    |> Enum.with_index(1)
    |> Enum.map(fn {{xml_id, el_name}, position} ->
      %{xml_id: xml_id, element: el_name, position: position}
    end)
  end

  defp walk_for_ids(node) do
    name = get_element_name(node)

    cond do
      name in @skip_elements ->
        []

      name in @container_elements or
          name in [
            "Legislation",
            "Body",
            "Primary",
            "Secondary",
            "Schedules",
            "EUBody",
            "EUPreamble",
            "Recitals"
          ] ->
        get_children_ids(node)

      name in @structural_elements ->
        xml_id = xpath(node, ~x"./@id"os) |> to_string_or_nil()
        entry = {xml_id, name}
        [entry | get_children_ids(node)]

      true ->
        get_children_ids(node)
    end
  end

  defp get_children_ids(node) do
    case xpath(node, ~x"./*"l) do
      nil -> []
      children -> Enum.flat_map(children, &walk_for_ids/1)
    end
  end

  defp get_element_name(node) do
    case xpath(node, ~x"name()"s) do
      nil -> nil
      "" -> nil
      name -> to_string(name)
    end
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(""), do: nil
  defp to_string_or_nil(val), do: to_string(val)

  # ── Data Loading ──────────────────────────────────────────────────

  defp lookup_law(law_name) do
    query = "SELECT type_code FROM legal_register WHERE name = $1 LIMIT 1"

    case SertantaiLegal.Repo.query(query, [law_name]) do
      {:ok, %{rows: [[type_code]]}} -> {:ok, %{type_code: type_code}}
      _ -> {:error, "law not found in legal_register"}
    end
  end

  defp load_existing_rows(law_name) do
    query = """
    SELECT section_id, position, section_type
    FROM legal_articles
    WHERE law_name = $1
    ORDER BY position
    """

    case SertantaiLegal.Repo.query(query, [law_name]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [section_id, position, section_type] ->
          %{section_id: section_id, position: position, section_type: section_type}
        end)

      _ ->
        []
    end
  end

  defp fetch_xml(law_name, _type_code) do
    slash_path = IdField.normalize_to_slash_format(law_name)
    path = "/#{slash_path}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} -> {:ok, xml}
      {:ok, :html, _html} -> {:error, "received HTML instead of XML"}
      {:error, _code, reason} -> {:error, reason}
    end
  end

  # ── Sense Checks ──────────────────────────────────────────────────

  defp sense_check(law_name, existing_rows, new_rows, old_xml_ids) do
    old_count = length(existing_rows)
    new_count = length(new_rows)
    xml_id_count = length(old_xml_ids)

    # Old xml_id count should match existing row count (same traversal)
    if xml_id_count != old_count do
      IO.puts("  ⚠ xml_id count (#{xml_id_count}) != existing rows (#{old_count})")
    end

    # New count should be <= old count (wrapper P2s removed)
    if new_count > old_count do
      IO.puts("  ⚠ new rows (#{new_count}) > old rows (#{old_count}) — unexpected!")
    end

    # New count shouldn't drop too far
    if new_count < old_count * 0.8 do
      IO.puts("  ⚠ new rows (#{new_count}) < 80% of old rows (#{old_count}) — large change!")
    end

    IO.puts("  rows: #{old_count} old → #{new_count} new (#{old_count - new_count} removed)")
  end

  # ── Build Corrections ────────────────────────────────────────────

  defp build_corrections(_law_name, existing_rows, new_rows, old_xml_ids) do
    # Map old xml_ids (with position) to existing section_ids
    old_by_xml_id =
      old_xml_ids
      |> Enum.zip(existing_rows)
      |> Enum.reduce(%{}, fn {xml_entry, existing}, acc ->
        if xml_entry.xml_id do
          Map.put(acc, xml_entry.xml_id, existing.section_id)
        else
          # No xml_id — use position as fallback key
          Map.put(acc, "pos:#{xml_entry.position}", existing.section_id)
        end
      end)

    # Map new rows by xml_id
    new_by_xml_id =
      new_rows
      |> Enum.reduce(%{}, fn row, acc ->
        if row.xml_id do
          Map.put(acc, row.xml_id, row.section_id)
        else
          Map.put(acc, "pos:#{row.position}", row.section_id)
        end
      end)

    # Build corrections from old side
    corrections =
      Enum.map(old_by_xml_id, fn {xml_id, old_section_id} ->
        case Map.get(new_by_xml_id, xml_id) do
          nil ->
            # Old row has no match in new parse → wrapper P2, delete
            %{
              xml_id: xml_id,
              old_section_id: old_section_id,
              new_section_id: nil,
              action: :delete
            }

          ^old_section_id ->
            # Same section_id → no change
            %{
              xml_id: xml_id,
              old_section_id: old_section_id,
              new_section_id: old_section_id,
              action: :no_change
            }

          new_section_id ->
            # Different section_id → rewrite
            %{
              xml_id: xml_id,
              old_section_id: old_section_id,
              new_section_id: new_section_id,
              action: :rewrite
            }
        end
      end)

    # Check for new rows that have no old match (shouldn't happen, but flag it)
    new_only_xml_ids = Map.keys(new_by_xml_id) -- Map.keys(old_by_xml_id)

    unmatched =
      Enum.map(new_only_xml_ids, fn xml_id ->
        %{
          xml_id: xml_id,
          old_section_id: nil,
          new_section_id: Map.get(new_by_xml_id, xml_id),
          action: :unmatched
        }
      end)

    corrections ++ unmatched
  end

  # ── Apply Corrections ────────────────────────────────────────────

  defp apply_corrections(corrections) do
    rewrites = Enum.filter(corrections, &(&1.action == :rewrite))
    deletes = Enum.filter(corrections, &(&1.action == :delete))

    SertantaiLegal.Repo.transaction(fn ->
      # Update downstream tables first (before PK changes)
      Enum.each(rewrites, fn c ->
        # control_mappings
        SertantaiLegal.Repo.query!(
          "UPDATE control_mappings SET section_id = $1 WHERE section_id = $2",
          [c.new_section_id, c.old_section_id]
        )

        # amendment_annotations.affected_sections (text array)
        SertantaiLegal.Repo.query!(
          "UPDATE amendment_annotations SET affected_sections = array_replace(affected_sections, $1, $2) WHERE $1 = ANY(affected_sections)",
          [c.old_section_id, c.new_section_id]
        )
      end)

      # Delete wrapper P2 rows from downstream tables
      Enum.each(deletes, fn c ->
        SertantaiLegal.Repo.query!(
          "DELETE FROM control_mappings WHERE section_id = $1",
          [c.old_section_id]
        )

        SertantaiLegal.Repo.query!(
          "UPDATE amendment_annotations SET affected_sections = array_remove(affected_sections, $1) WHERE $1 = ANY(affected_sections)",
          [c.old_section_id]
        )
      end)

      # Now update the PKs in legal_articles
      Enum.each(rewrites, fn c ->
        SertantaiLegal.Repo.query!(
          "UPDATE legal_articles SET section_id = $1 WHERE section_id = $2",
          [c.new_section_id, c.old_section_id]
        )
      end)

      # Delete wrapper P2 rows from legal_articles
      Enum.each(deletes, fn c ->
        SertantaiLegal.Repo.query!(
          "DELETE FROM legal_articles WHERE section_id = $1",
          [c.old_section_id]
        )
      end)

      IO.puts("  Applied #{length(rewrites)} rewrites, #{length(deletes)} deletes")
    end)
  end

  # ── Find affected laws ────────────────────────────────────────────

  defp find_affected_laws do
    query = """
    SELECT DISTINCT law_name FROM legal_articles
    WHERE section_id ~ '\\.(\\d+[A-Za-z]*)\\(\\1\\)'
    ORDER BY law_name
    """

    case SertantaiLegal.Repo.query(query, []) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [name] -> name end)
      _ -> []
    end
  end
end
