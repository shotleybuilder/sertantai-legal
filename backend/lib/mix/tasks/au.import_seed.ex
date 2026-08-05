defmodule Mix.Tasks.Au.ImportSeed do
  @moduledoc """
  Import Australian EHS/HR laws from a markdown seed file into legal_register_au.

  ## Usage

      mix au.import_seed                           # Default: backend/data/combined-xdeduped.md
      mix au.import_seed path/to/file.md           # Custom file
      mix au.import_seed --dry-run                 # Parse and report without importing

  ## Seed Format

  Markdown file with section headers and bullet-point law titles:

      ## section-name.md
      - Work Health and Safety Act 2011
      - Environment Protection Act 2017
      - Code of practice: Confined spaces

  Entries are deduped by title. Section headers are ignored for family classification —
  family is inferred from title keywords via Countries.Au.family_keywords/0.
  """

  use Mix.Task

  alias SertantaiLegal.Countries.Au
  alias SertantaiLegal.Legal.LegalRegister

  @default_file "data/combined-xdeduped.md"

  # Category → family mapping. Categories are EHS/HR topic areas from the seed file.
  # Each maps to the closest AU family from Countries.Au.family_keywords/0.
  @category_to_family %{
    "safety-management" => "💙 OH&S: Occupational / Personal Safety",
    "safety-technical" => "💙 OH&S: Occupational / Personal Safety",
    "health-management" => "💙 HEALTH: Public",
    "emergency" => "💙 FIRE",
    "general-environmental" => "💚 ENVIRONMENTAL PROTECTION",
    "air-emissions" => "💚 AIR QUALITY",
    "water-management" => "💚 WATER & WASTEWATER",
    "waste-management" => "💚 WASTE",
    "chemicals-management" => "💙 FIRE: Dangerous and Explosive Substances",
    "hazardous-materials" => "💙 FIRE: Dangerous and Explosive Substances",
    "admin-legal-structure" => nil
  }

  # Priority order: most specific categories first for family assignment.
  # When a title appears in multiple categories, the first match in this list wins.
  @category_priority [
    "air-emissions",
    "water-management",
    "waste-management",
    "chemicals-management",
    "hazardous-materials",
    "emergency",
    "safety-technical",
    "safety-management",
    "health-management",
    "general-environmental",
    "admin-legal-structure"
  ]

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)
    file = List.first(rest) || @default_file

    unless File.exists?(file) do
      Mix.shell().error("File not found: #{file}")
      System.halt(1)
    end

    Mix.Task.run("app.start")

    Mix.shell().info("Parsing #{file}...")
    entries = parse_file(file)
    Mix.shell().info("Parsed #{length(entries)} unique entries")

    # Report stats
    report_stats(entries)

    if dry_run? do
      Mix.shell().info("\n[DRY RUN] No records imported.")
      report_samples(entries)
    else
      Mix.shell().info("\nImporting into legal_register_au...")
      {created, skipped, errors} = import_entries(entries)

      Mix.shell().info("""
      \nImport complete:
        Created: #{created}
        Skipped (already exists): #{skipped}
        Errors: #{errors}
      """)
    end
  end

  # ── Parsing ─────────────────────────────────────────────────────────

  defp parse_file(file) do
    lines = file |> File.read!() |> String.split("\n")

    # First pass: collect title → [categories] mapping
    {raw_entries, _} =
      Enum.reduce(lines, {[], nil}, fn line, {acc, current_cat} ->
        cond do
          String.starts_with?(line, "## ") ->
            cat = line |> String.trim_leading("## ") |> String.trim_trailing(".md")
            {acc, cat}

          String.starts_with?(line, "- ") and current_cat != nil ->
            title =
              line
              |> String.trim_leading("- ")
              |> String.trim()
              |> String.trim_trailing("*")
              |> String.trim()

            {[{title, current_cat} | acc], current_cat}

          true ->
            {acc, current_cat}
        end
      end)

    # Group by title → unique list of categories
    by_title =
      raw_entries
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {title, cats} -> {title, Enum.uniq(cats)} end)

    # Build entries with category-aware family assignment
    by_title
    |> Enum.map(fn {title, categories} -> parse_entry(title, categories) end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_entry(title, categories) do
    keyword_family = infer_family(title)
    {cat_family, cat_family_ii} = infer_family_from_categories(categories)

    # Keyword match wins if available; otherwise fall back to category inference
    family = keyword_family || cat_family

    family_ii =
      if keyword_family && cat_family && keyword_family != cat_family,
        do: cat_family,
        else: cat_family_ii

    %{
      title_en: title,
      year: extract_year(title),
      jurisdiction: infer_jurisdiction(title),
      type_code: infer_type_code(title),
      type_class: Au.type_class_from_title(title),
      family: family,
      family_ii: family_ii,
      name: build_name(title)
    }
  end

  # Infer family and family_ii from the categories a title appears under.
  # Uses priority ordering — most specific categories win.
  defp infer_family_from_categories(categories) do
    # Sort categories by priority (most specific first)
    sorted =
      @category_priority
      |> Enum.filter(&(&1 in categories))
      |> Enum.map(&{&1, Map.get(@category_to_family, &1)})
      |> Enum.reject(fn {_, family} -> is_nil(family) end)
      |> Enum.uniq_by(&elem(&1, 1))

    case sorted do
      [{_, primary} | [{_, secondary} | _]] -> {primary, secondary}
      [{_, primary} | _] -> {primary, nil}
      [] -> {nil, nil}
    end
  end

  # ── Year Extraction ─────────────────────────────────────────────────

  defp extract_year(title) do
    # Match a 4-digit year (1900-2099) near the end of the title
    case Regex.run(~r/\b((?:19|20)\d{2})\b/, title) do
      [_, year] -> String.to_integer(year)
      _ -> nil
    end
  end

  # ── Jurisdiction Inference ──────────────────────────────────────────

  defp jurisdiction_patterns, do: [
    # Explicit parenthetical codes
    {~r/\(NSW\)/i, "nsw"},
    {~r/\(Qld\)|Queensland\)/i, "qld"},
    {~r/\(ACT\)/i, "act"},
    {~r/\(Vic\)/i, "vic"},
    {~r/\(SA\)|South Australia\)/i, "sa"},
    {~r/\(WA\)/i, "wa"},
    {~r/\(Tas\)/i, "tas"},
    {~r/\(NT\)|Northern Territory\)/i, "nt"},
    # State names in title
    {~r/New South Wales|(?<!\()NSW(?!\))/, "nsw"},
    {~r/\bVictori(?:a|an)\b/, "vic"},
    {~r/\bQueensland\b/, "qld"},
    {~r/\bSouth Australi(?:a|an)\b/, "sa"},
    {~r/\bWestern Australi(?:a|an)\b/, "wa"},
    {~r/\bTasmani(?:a|an)\b/, "tas"},
    {~r/\bNorthern Territory\b/, "nt"},
    {~r/\bACT\b/, "act"},
    # Commonwealth indicators
    {~r/\bCommonwealth\b/i, "cth"},
    {~r/\bNational Uniform Legislation\b/i, "cth"}
  ]

  defp infer_jurisdiction(title) do
    Enum.find_value(jurisdiction_patterns(), "cth", fn {pattern, jurisdiction} ->
      if Regex.match?(pattern, title), do: jurisdiction
    end)
  end

  # ── Type Code Inference ─────────────────────────────────────────────

  defp infer_type_code(title) do
    cond do
      Regex.match?(~r/\bAct\b/, title) -> "act"
      Regex.match?(~r/\bRegulations?\b/, title) -> "reg"
      Regex.match?(~r/\bRules?\b/, title) -> "rule"
      Regex.match?(~r/\bObjective\b/, title) -> "obj"
      Regex.match?(~r/Code of [Pp]ractice|Compliance [Cc]ode/i, title) -> "cop"
      Regex.match?(~r/\bAS(?:\/NZS)?\s/, title) -> "standard"
      Regex.match?(~r/\bNEPM\b|National Environment Protection.*Measure/i, title) -> "nepm"
      Regex.match?(~r/\bOrder\b|\bDetermination\b|\bNotice\b|\bPolicy\b/, title) -> "li"
      true -> "li"
    end
  end

  # ── Family Inference ────────────────────────────────────────────────

  defp infer_family(title) do
    lower = String.downcase(title)

    Au.family_keywords()
    |> Enum.find_value(fn {family, keywords} ->
      if Enum.any?(keywords, &String.contains?(lower, String.downcase(&1))), do: family
    end)
  end

  # ── Name Generation ─────────────────────────────────────────────────

  defp build_name(title) do
    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")
      |> String.slice(0, 80)

    "AU_#{slug}"
  end

  # ── Import ──────────────────────────────────────────────────────────

  defp import_entries(entries) do
    require Ash.Query

    Enum.reduce(entries, {0, 0, 0}, fn entry, {created, skipped, errors} ->
      # Check if already exists by name
      case LegalRegister
           |> Ash.Query.filter(name == ^entry.name and country == "au")
           |> Ash.read() do
        {:ok, [_ | _]} ->
          {created, skipped + 1, errors}

        _ ->
          attrs =
            %{
              country: "au",
              jurisdiction: entry.jurisdiction,
              name: entry.name,
              title_en: entry.title_en,
              year: entry.year,
              type_code: entry.type_code,
              type_class: entry.type_class,
              family: entry.family,
              family_ii: entry.family_ii
            }
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()

          case LegalRegister
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create() do
            {:ok, _} -> {created + 1, skipped, errors}
            {:error, _} -> {created, skipped, errors + 1}
          end
      end
    end)
  end

  # ── Reporting ───────────────────────────────────────────────────────

  defp report_stats(entries) do
    total = length(entries)
    by_jurisdiction = Enum.frequencies_by(entries, & &1.jurisdiction)
    by_type = Enum.frequencies_by(entries, & &1.type_code)
    with_family = Enum.count(entries, & &1.family)
    with_family_ii = Enum.count(entries, & &1.family_ii)
    with_year = Enum.count(entries, & &1.year)

    Mix.shell().info("""
    \n  Jurisdictions: #{inspect(by_jurisdiction |> Enum.sort_by(&elem(&1, 1), :desc))}
      Type codes (top 10): #{inspect(by_type |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10))}
      With family: #{with_family}/#{total} (#{Float.round(with_family / total * 100, 1)}%)
      With family_ii: #{with_family_ii}/#{total} (#{Float.round(with_family_ii / total * 100, 1)}%)
      With year: #{with_year}/#{total} (#{Float.round(with_year / total * 100, 1)}%)
    """)
  end

  defp report_samples(entries) do
    Mix.shell().info("\n=== Sample entries (first 10) ===")

    entries
    |> Enum.take(10)
    |> Enum.each(fn e ->
      Mix.shell().info(
        "  #{e.name}\n    title: #{e.title_en}\n    jurisdiction: #{e.jurisdiction}, type: #{e.type_code}, year: #{e.year || "?"}, family: #{e.family || "?"}\n"
      )
    end)

    # Show entries without family
    no_family = Enum.filter(entries, &is_nil(&1.family))

    if length(no_family) > 0 do
      Mix.shell().info("\n=== Without family (first 10 of #{length(no_family)}) ===")

      no_family
      |> Enum.take(10)
      |> Enum.each(fn e ->
        Mix.shell().info("  #{e.title_en}")
      end)
    end
  end
end
