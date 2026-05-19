defmodule Mix.Tasks.Au.ImportState do
  @moduledoc """
  Import per-state AU law lists to assign correct jurisdiction.

  Each file represents one jurisdiction. Titles are matched against existing
  records in legal_register_au — if found, jurisdiction is corrected. If not
  found, a new record is created.

  ## Usage

      mix au.import_state nsw backend/data/new-south-wales.md
      mix au.import_state nt backend/data/northern-territories.md
      mix au.import_state vic backend/data/victoria.md
      mix au.import_state --dry-run nsw backend/data/new-south-wales.md

  ## File Format

  Markdown list items, optionally with links (links are ignored):

      - [Title Text](url)       →  extracts "Title Text"
      - Plain Title Text        →  extracts "Plain Title Text"
  """

  use Mix.Task

  alias SertantaiLegal.Countries.Au
  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  @valid_jurisdictions Au.jurisdictions() |> Enum.map(&elem(&1, 0))

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)

    case positional do
      [jurisdiction, file] ->
        unless jurisdiction in @valid_jurisdictions do
          Mix.shell().error(
            "Invalid jurisdiction: #{jurisdiction}. Valid: #{Enum.join(@valid_jurisdictions, ", ")}"
          )

          System.halt(1)
        end

        unless File.exists?(file) do
          Mix.shell().error("File not found: #{file}")
          System.halt(1)
        end

        Mix.Task.run("app.start")
        process_file(jurisdiction, file, dry_run?)

      _ ->
        Mix.shell().error("Usage: mix au.import_state <jurisdiction> <file.md> [--dry-run]")
        System.halt(1)
    end
  end

  defp process_file(jurisdiction, file, dry_run?) do
    titles = parse_file(file)
    Mix.shell().info("Parsed #{length(titles)} titles for #{jurisdiction} from #{file}")

    # Load all existing AU records indexed by title for fast lookup
    existing = load_existing_records()
    Mix.shell().info("Loaded #{map_size(existing)} existing AU records")

    {updated, created, already_correct, skipped} =
      Enum.reduce(titles, {0, 0, 0, 0}, fn title, {upd, cre, correct, skip} ->
        case Map.get(existing, normalize_title(title)) do
          nil ->
            # New record — not in our database yet
            if dry_run? do
              Mix.shell().info("  + NEW: #{title}")
            else
              create_record(title, jurisdiction)
            end

            {upd, cre + 1, correct, skip}

          records when is_list(records) ->
            # Exists — check if jurisdiction needs correcting
            record = List.first(records)

            cond do
              record.jurisdiction == jurisdiction ->
                {upd, cre, correct + 1, skip}

              record.jurisdiction == "cth" ->
                # Was defaulting to cth, now we know it's a state law
                if dry_run? do
                  Mix.shell().info("  ↻ FIX: #{title} (cth → #{jurisdiction})")
                else
                  update_jurisdiction(record, jurisdiction)
                end

                {upd + 1, cre, correct, skip}

              true ->
                # Already assigned to a different state — might be multi-jurisdiction
                # Don't overwrite, just note it
                if dry_run? do
                  Mix.shell().info(
                    "  ⊘ SKIP: #{title} (already #{record.jurisdiction}, also in #{jurisdiction})"
                  )
                end

                {upd, cre, correct, skip + 1}
            end
        end
      end)

    prefix = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""
    \n#{prefix}Import complete for #{jurisdiction}:
      Updated jurisdiction (cth → #{jurisdiction}): #{updated}
      Created new records: #{created}
      Already correct: #{already_correct}
      Skipped (different state): #{skipped}
    """)
  end

  # ── Parsing ─────────────────────────────────────────────────────────

  defp parse_file(file) do
    file
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "- "))
    |> Enum.map(&extract_title/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  # Extract title from either `- [Title](url)` or `- Title` format
  defp extract_title(line) do
    line = String.trim_leading(line, "- ")

    case Regex.run(~r/^\[([^\]]+)\]/, line) do
      [_, title] -> String.trim(title)
      nil -> line |> String.trim() |> String.trim_trailing("*") |> String.trim()
    end
  end

  # ── Lookup ──────────────────────────────────────────────────────────

  defp load_existing_records do
    case LegalRegister
         |> Ash.Query.filter(country == "au")
         |> Ash.Query.select([:id, :title_en, :jurisdiction, :name])
         |> Ash.read() do
      {:ok, records} when is_list(records) ->
        Enum.group_by(records, &normalize_title(&1.title_en))

      _ ->
        %{}
    end
  end

  defp normalize_title(nil), do: ""
  defp normalize_title(title), do: title |> String.downcase() |> String.trim()

  # ── Mutations ───────────────────────────────────────────────────────

  defp update_jurisdiction(record, jurisdiction) do
    type_code = infer_type_code(record.title_en, jurisdiction)

    attrs =
      %{jurisdiction: jurisdiction}
      |> maybe_put(:type_code, type_code)

    case record
         |> Ash.Changeset.for_update(:update, attrs)
         |> Ash.update() do
      {:ok, _} -> :ok
      {:error, reason} -> Mix.shell().error("  Update failed: #{inspect(reason)}")
    end
  end

  defp create_record(title, jurisdiction) do
    attrs = %{
      country: "au",
      jurisdiction: jurisdiction,
      title_en: title,
      name: build_name(title),
      year: extract_year(title),
      type_code: infer_type_code(title, jurisdiction),
      type_class: Au.type_class_from_title(title),
      family: infer_family(title)
    }

    case LegalRegister
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create() do
      {:ok, _} -> :ok
      {:error, reason} -> Mix.shell().error("  Create failed for #{title}: #{inspect(reason)}")
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp extract_year(title) do
    case Regex.run(~r/\b((?:19|20)\d{2})\b/, title) do
      [_, year] -> String.to_integer(year)
      _ -> nil
    end
  end

  defp infer_type_code(title, jurisdiction) do
    type =
      cond do
        Regex.match?(~r/\bAct\b/, title) -> "act"
        Regex.match?(~r/\bRegulations?\b/, title) -> "reg"
        Regex.match?(~r/\bRules?\b/, title) -> "rule"
        Regex.match?(~r/Code of [Pp]ractice|Compliance [Cc]ode/i, title) -> "cop"
        Regex.match?(~r/\bAS(?:\/NZS)?\s/, title) -> "standard"
        true -> "li"
      end

    case type do
      "cop" -> "cop"
      "standard" -> "standard"
      _ -> "#{jurisdiction}_#{type}"
    end
  end

  defp infer_family(title) do
    lower = String.downcase(title)

    Au.family_keywords()
    |> Enum.find_value(fn {family, keywords} ->
      if Enum.any?(keywords, &String.contains?(lower, String.downcase(&1))), do: family
    end)
  end

  defp build_name(title) do
    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")
      |> String.slice(0, 80)

    "AU_#{slug}"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
